import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import axios from "axios";

admin.initializeApp();
const db = admin.firestore();

// ── Types ────────────────────────────────────────────────────────────────────

export interface ScoreCriteres {
  scoreActivite: number;   // 0-100 : Agriculture=80, Energie=90, Recyclage=85...
  scoreUemoa: number;      // 0-100 : Conforme=100, Partiel=60, NonConforme=20
  scoreCo2: number;        // 0-100 : calculé sur réduction CO2
  scoreCertif: number;     // 0-100 : par certification
  scoreResilience: number; // 0-100 : capacité de résilience
  bonusFormation: number;  // 0-15 : +2 à +5 pts par cours certifié
}

export interface ScoreInput {
  userId: string;
  typeActivite: string;
  alignementUemoa: string; // "Oui" | "Partiel" | "Non"
  reductionCo2: number;    // tonnes/an
  certifications: string[];
  resilience: number;      // 1-5
}

// ── Constantes métier ────────────────────────────────────────────────────────

export const SCORE_ACTIVITE_MAP: Record<string, number> = {
  Agriculture: 75,
  "Énergie renouvelable": 90,
  Recyclage: 85,
  "Transport propre": 80,
  "Forêt / Agroforesterie": 88,
  "Pêche durable": 70,
  Autre: 50,
};

// Les libellés courts ("Bio", "Équitable") sont ceux affichés par le
// formulaire de scoring (scoring_form_screen.dart) ; les libellés longs
// restent acceptés pour compat avec d'anciens appels. Alignés sur
// ScoreRepository._certifMap côté Dart (repli local).
export const SCORE_CERTIF_MAP: Record<string, number> = {
  "Bio": 25,
  "Agriculture biologique": 25,
  "Équitable": 20,
  "Commerce équitable": 20,
  "ISO 14001": 30,
  "Carbone Neutre": 25,
};

export const UEMOA_SCORE_MAP: Record<string, number> = {
  Oui: 100,
  Partiel: 60,
  Non: 20,
};

/**
 * Calcule le Score Climat ESG selon la formule du CDC :
 * Score = (Activité×0.25) + (UEMOA×0.20) + (CO2×0.20) + (Certif×0.20) + (Résilience×0.15) + BonusFormation
 */
export function calculerScore(input: ScoreCriteres): number {
  const score =
    input.scoreActivite * 0.25 +
    input.scoreUemoa * 0.20 +
    input.scoreCo2 * 0.20 +
    input.scoreCertif * 0.20 +
    input.scoreResilience * 0.15 +
    input.bonusFormation;

  // Borne basse en plus de la borne haute : un critère hors plage (ex.
  // resilience négatif, non revalidé côté client) ne doit jamais produire
  // un score total négatif.
  return Math.max(0, Math.min(100, Math.round(score * 10) / 10));
}

export function co2ToScore(reductionCo2: number): number {
  if (reductionCo2 >= 500) return 100;
  if (reductionCo2 >= 200) return 80;
  if (reductionCo2 >= 100) return 60;
  if (reductionCo2 >= 50) return 40;
  if (reductionCo2 > 0) return 20;
  return 0;
}

export function certifToScore(certifications: string[]): number {
  const total = certifications.reduce((sum, c) => sum + (SCORE_CERTIF_MAP[c] ?? 0), 0);
  return Math.max(0, Math.min(100, total));
}

export function resilienceToScore(resilience: number): number {
  return Math.max(0, Math.min(100, resilience * 20));
}

async function getBonusFormation(userId: string): Promise<number> {
  const progressSnap = await db
    .collection("users")
    .doc(userId)
    .collection("progress")
    .where("statut", "==", "TERMINE")
    .get();

  const completedCourses = progressSnap.size;
  const badgesSnap = await db
    .collection("users")
    .doc(userId)
    .collection("badges")
    .where("dateObtention", "!=", null)
    .get();

  const badges = badgesSnap.size;
  // +2 pts par cours, +3 pts par badge certifié, max 15 pts
  return Math.min(15, completedCourses * 2 + badges * 3);
}

// Paliers CDC §3 : 0-29 Insuffisant · 30-59 Intermédiaire · 60-79 Bon · 80-100 Excellent
// (alignés sur ScoreClimatModel.niveauFromScore côté Flutter).
export function determineNiveau(score: number): string {
  if (score >= 80) return "excellent";
  if (score >= 60) return "bon";
  if (score >= 30) return "intermediaire";
  return "insuffisant";
}

function genererSuggestions(input: ScoreCriteres, scoreTotal: number): string[] {
  const suggestions: string[] = [];
  if (input.scoreCo2 < 60) {
    suggestions.push("Documentez votre réduction d'émissions CO₂ pour améliorer votre score.");
  }
  if (input.scoreUemoa < 60) {
    suggestions.push("Alignez votre activité avec la taxonomie UEMOA verte.");
  }
  if (input.scoreCertif < 40) {
    suggestions.push("Obtenez une certification (Agriculture Bio, ISO 14001...) pour +25 pts.");
  }
  if (input.bonusFormation < 8) {
    suggestions.push("Complétez davantage de formations pour gagner des points bonus.");
  }
  if (scoreTotal < 60) {
    suggestions.push("Score < 60 : vous ne pouvez pas encore accéder au financement vert.");
  }
  return suggestions;
}

// ── Cloud Function : calculerScoreClimat ─────────────────────────────────────

export const calculerScoreClimat = functions
  .region("europe-west1")
  .https.onCall(async (data: ScoreInput, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentification requise.");
    }
    if (context.auth.uid !== data.userId) {
      throw new functions.https.HttpsError("permission-denied", "Accès non autorisé.");
    }

    const bonusFormation = await getBonusFormation(data.userId);

    const criteres: ScoreCriteres = {
      scoreActivite: SCORE_ACTIVITE_MAP[data.typeActivite] ?? 50,
      scoreUemoa: UEMOA_SCORE_MAP[data.alignementUemoa] ?? 20,
      scoreCo2: co2ToScore(data.reductionCo2),
      scoreCertif: certifToScore(data.certifications),
      scoreResilience: resilienceToScore(data.resilience),
      bonusFormation,
    };

    const scoreTotal = calculerScore(criteres);
    const niveau = determineNiveau(scoreTotal);
    const suggestions = genererSuggestions(criteres, scoreTotal);

    // Schéma identique à ScoreRepository.saveScore() côté Dart (repli local) —
    // c'est ScoreClimatModel.fromFirestore / ScoreCriteres.fromMap qui relisent
    // ce document (historique, résultat) : les clés doivent correspondre
    // exactement, y compris pour le sous-objet "criteres".
    const criteresDoc = {
      activite: criteres.scoreActivite,
      uemoa: criteres.scoreUemoa,
      co2: criteres.scoreCo2,
      certif: criteres.scoreCertif,
      resilience: criteres.scoreResilience,
      bonus_formation: criteres.bonusFormation,
    };
    const scoreDoc = {
      userId: data.userId,
      score_total: scoreTotal,
      criteres: criteresDoc,
      niveau,
      suggestions,
      date_calcul: admin.firestore.FieldValue.serverTimestamp(),
      version_algo: "v1-cloud",
    };

    const docRef = await db.collection("scores_climat").add(scoreDoc);
    // criteres inclus explicitement : le client (ScoreRepository.calculate)
    // construit son ScoreClimatModel depuis cette réponse, pas depuis une
    // relecture Firestore.
    return { scoreId: docRef.id, scoreTotal, criteres: criteresDoc, niveau, suggestions };
  });

// ── Émission de badges OpenBadge (J5.10, CDC §2.3) ───────────────────────────

// Assertion OpenBadge v2 minimale (https://www.imsglobal.org/spec/ob/v2p0) —
// suffisante pour être vérifiable/affichable ; les champs optionnels
// (evidence, expires, image embarquée) restent hors du périmètre de cette
// tâche.
export interface OpenBadgeAssertion {
  "@context": "https://w3id.org/openbadges/v2";
  type: "Assertion";
  id: string;
  recipient: { type: "id"; identity: string };
  badge: string;
  issuedOn: string;
  verification: { type: "hosted" };
}

export interface BadgeIssuer {
  issueBadge(params: {
    userId: string;
    badgeId: string;
    badgeName: string;
  }): Promise<{ url: string; assertion: OpenBadgeAssertion }>;
}

// Mock tracé, sans appel réseau réel — utilisé tant que le compte OpenBadge
// Factory (ou Badgr) n'est pas approvisionné. `issuedBadges` rend chaque
// émission vérifiable en test, comme `MockWhatsAppChannel.sentMessages`.
export class MockOpenBadgeIssuer implements BadgeIssuer {
  readonly issuedBadges: { userId: string; badgeId: string; assertion: OpenBadgeAssertion }[] = [];

  async issueBadge(params: {
    userId: string;
    badgeId: string;
    badgeName: string;
  }): Promise<{ url: string; assertion: OpenBadgeAssertion }> {
    const { userId, badgeId } = params;
    const url = `https://badges.greenaccess.test/assertions/${userId}-${badgeId}`;
    const assertion: OpenBadgeAssertion = {
      "@context": "https://w3id.org/openbadges/v2",
      type: "Assertion",
      id: url,
      recipient: { type: "id", identity: userId },
      badge: `https://badges.greenaccess.test/badgeclass/${badgeId}`,
      issuedOn: new Date().toISOString(),
      verification: { type: "hosted" },
    };
    this.issuedBadges.push({ userId, badgeId, assertion });
    functions.logger.info(`[MockOpenBadgeIssuer] Badge ${badgeId} émis pour ${userId} → ${url}`);
    return { url, assertion };
  }
}

export const defaultBadgeIssuer: BadgeIssuer = new MockOpenBadgeIssuer();

// ── Cloud Function : onCourseCompleted ───────────────────────────────────────

export const onCourseCompleted = functions
  .region("europe-west1")
  .firestore.document("users/{userId}/progress/{courseId}")
  .onWrite(async (change, context) => {
    const after = change.after.data();
    if (!after || after.statut !== "TERMINE") return;

    const { userId, courseId } = context.params;

    // Récupérer les infos du cours
    const courseSnap = await db.collection("courses").doc(courseId).get();
    const course = courseSnap.data();
    if (!course) return;

    // Déclencher badge si défini
    if (course.badge_id && after.badge_declenche) {
      const badgeRef = db.collection("users").doc(userId).collection("badges").doc(course.badge_id);
      const badgeSnap = await badgeRef.get();
      if (!badgeSnap.exists) {
        // J5.10-J5.12 : émission OpenBadge (assertion v2 + URL, J5.10),
        // conservée dans openbadge_url (J5.11) plutôt que codée en dur à
        // `null` comme avant le branchement du BadgeIssuer sur ce
        // déclencheur (J5.12).
        const { url } = await defaultBadgeIssuer.issueBadge({
          userId,
          badgeId: course.badge_id,
          badgeName: course.titre ?? course.badge_id,
        });

        // `date_obtention` (snake_case) — le champ était écrit en
        // `dateObtention` (camelCase) avant cette tâche, alors que
        // `BadgeModel.fromFirestore` (lib/models/badge_model.dart) lit
        // exclusivement `date_obtention` : un badge délivré par ce
        // déclencheur s'affichait donc avec `dateObtention: null` côté app
        // (`BadgeModel.isObtenu` toujours faux), en silence. Corrigé au
        // passage, dans le même esprit que le bug partenaire_id/partenaireId
        // de J5.5.
        await badgeRef.set({
          date_obtention: admin.firestore.FieldValue.serverTimestamp(),
          courseId,
          openbadge_url: url,
        });

        functions.logger.info(`Badge ${course.badge_id} déclenché pour ${userId}.`);
      }
    }
  });

// ── Cloud Function : onDemandeSubmitted ──────────────────────────────────────

// Extrait pour être testable indépendamment de admin.messaging() (aucun
// émulateur FCM n'existe dans la Firebase Emulator Suite — appeler
// messaging() en test contacterait un vrai serveur Google). Voir
// functions/test/triggers.test.ts.
export async function getPartenaireFinanceurTokens(): Promise<string[]> {
  const partenairesSnap = await db
    .collection("users")
    .where("role", "==", "partenaireFinanceur")
    .get();

  const tokens: string[] = [];
  partenairesSnap.forEach((doc) => {
    if (doc.data().fcm_token) tokens.push(doc.data().fcm_token);
  });
  return tokens;
}

export const onDemandeSubmitted = functions
  .region("europe-west1")
  .firestore.document("demandes_financement/{demandeId}")
  .onCreate(async (snap, context) => {
    const demande = snap.data();
    if (!demande || demande.statut !== "soumis") return;

    const tokens = await getPartenaireFinanceurTokens();

    if (tokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "Nouvelle demande de financement",
          body: `${demande.montant} FCFA — ${demande.type_projet} (${demande.pays})`,
        },
        data: { demandeId: context.params.demandeId },
      });
    }

    functions.logger.info(`Demande ${context.params.demandeId} notifiée à ${tokens.length} partenaires.`);
  });

// ── Canal de secours WhatsApp (J5.7, CDC §2.3) ───────────────────────────────

// Interface abstraite : permet de brancher un vrai client WhatsApp Business
// API plus tard sans toucher à NotificationService.sendBestEffort() (J5.8).
export interface WhatsAppChannel {
  sendMessage(phoneNumber: string, message: string): Promise<boolean>;
}

// Mock tracé, sans appel réseau réel — utilisé tant que le compte WhatsApp
// Business API n'est pas approvisionné. `sentMessages` rend les envois
// vérifiables en test.
export class MockWhatsAppChannel implements WhatsAppChannel {
  readonly sentMessages: { phoneNumber: string; message: string }[] = [];

  async sendMessage(phoneNumber: string, message: string): Promise<boolean> {
    this.sentMessages.push({ phoneNumber, message });
    functions.logger.info(`[MockWhatsApp] → ${phoneNumber} : ${message}`);
    return true;
  }
}

// ── NotificationService : sélection automatique de canal (J5.8, CDC §2.3) ───

// `sendFcm` est injectable pour rester testable : le namespace `admin`
// importé en `import * as admin` est figé et non mockable (voir
// checkAlertesClimatiques.test.ts et README.md §7), contrairement à une
// fonction passée en paramètre de constructeur.
export type FcmSender = (
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
) => Promise<void>;

const defaultFcmSender: FcmSender = async (token, title, body, data) => {
  await admin.messaging().sendEachForMulticast({
    tokens: [token],
    notification: { title, body },
    data,
  });
};

// Garantit la délivrance d'une notification critique : tente FCM en premier,
// puis se rabat sur WhatsApp (zone à faible signal, app pas toujours
// joignable en push, cf. CDC §2.3) si FCM échoue ou si aucun token FCM n'est
// disponible. "Best effort" : ne lève jamais, renvoie le canal effectivement
// utilisé.
export class NotificationService {
  constructor(
    private readonly whatsapp: WhatsAppChannel,
    private readonly sendFcm: FcmSender = defaultFcmSender
  ) {}

  async sendBestEffort(params: {
    fcmToken?: string | null;
    phoneNumber?: string | null;
    title: string;
    body: string;
    data?: Record<string, string>;
  }): Promise<"fcm" | "whatsapp" | "none"> {
    const { fcmToken, phoneNumber, title, body, data } = params;

    if (fcmToken) {
      try {
        await this.sendFcm(fcmToken, title, body, data);
        return "fcm";
      } catch (e) {
        functions.logger.warn(`FCM indisponible, repli WhatsApp : ${e}`);
      }
    }

    if (phoneNumber) {
      const envoye = await this.whatsapp.sendMessage(phoneNumber, `${title}\n${body}`);
      if (envoye) return "whatsapp";
    }

    return "none";
  }
}

export const defaultWhatsAppChannel = new MockWhatsAppChannel();
const notificationService = new NotificationService(defaultWhatsAppChannel);

// ── Cloud Function : onMessageSent ───────────────────────────────────────────

// Extraite pour être testable indépendamment de admin.messaging() (même
// contrainte que getPartenaireFinanceurTokens ci-dessus). Le destinataire est
// "l'autre partie" de la conversation : si l'auteur est le demandeur, on
// notifie le partenaire financeur assigné à la demande (aucune notification
// si aucun partenaire n'est encore assigné) ; sinon (l'auteur est le
// partenaire ou un admin), on notifie le demandeur.
export async function getDestinataireContact(
  demandeUserId: string,
  demandePartenaireId: string | undefined,
  auteurId: string
): Promise<{ fcmToken: string | null; phoneNumber: string | null }> {
  const destinataireId = auteurId === demandeUserId ? demandePartenaireId : demandeUserId;
  if (!destinataireId) return { fcmToken: null, phoneNumber: null };

  const userSnap = await db.collection("users").doc(destinataireId).get();
  const data = userSnap.data();
  return {
    fcmToken: data?.fcm_token ?? null,
    phoneNumber: data?.telephone ?? null,
  };
}

export const onMessageSent = functions
  .region("europe-west1")
  .firestore.document("demandes_financement/{demandeId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    if (!message) return;

    const demandeSnap = await db
      .collection("demandes_financement")
      .doc(context.params.demandeId)
      .get();
    const demande = demandeSnap.data();
    if (!demande) return;

    const contact = await getDestinataireContact(demande.userId, demande.partenaire_id, message.auteur_id);
    if (!contact.fcmToken && !contact.phoneNumber) {
      functions.logger.info(`Message ${context.params.messageId} : aucun destinataire à notifier.`);
      return;
    }

    const canal = await notificationService.sendBestEffort({
      fcmToken: contact.fcmToken,
      phoneNumber: contact.phoneNumber,
      title: `Nouveau message de ${message.auteur_nom}`,
      body: message.contenu,
      data: { demandeId: context.params.demandeId },
    });

    functions.logger.info(`Message ${context.params.messageId} notifié via ${canal}.`);
  });

// ── Cloud Function : onAlertClimatique (schedulée) ───────────────────────────

export type TypeAlerte = "secheresse" | "inondation" | "chaleur" | null;

/**
 * Seuils de détection d'aléa climatique à partir des prévisions Open-Meteo
 * du jour (extrait pour être testable sans réseau ni Firestore). Priorité
 * en cas de cumul : inondation > chaleur > sécheresse (même ordre que
 * l'ancien enchaînement de ternaires dans checkAlertesClimatiques).
 */
export function detecterAlerte(precipMm: number, tempMax: number): TypeAlerte {
  if (precipMm > 80) return "inondation";
  if (tempMax > 40) return "chaleur";
  if (precipMm < 2 && tempMax > 35) return "secheresse";
  return null;
}

function messageAlerte(typeAlerte: TypeAlerte, zoneNom: string, precipMm: number, tempMax: number): string {
  switch (typeAlerte) {
    case "inondation":
      return `Alerte inondation : ${precipMm}mm prévus dans la zone ${zoneNom}`;
    case "chaleur":
      return `Alerte chaleur extrême : ${tempMax}°C prévus dans la zone ${zoneNom}`;
    case "secheresse":
      return `Alerte sécheresse : précipitations insuffisantes dans la zone ${zoneNom}`;
    default:
      return "";
  }
}

export const checkAlertesClimatiques = functions
  .region("europe-west1")
  .pubsub.schedule("every 24 hours")
  .onRun(async () => {
    // Vérifier les alertes météo via API publique (OpenMeteo)
    const zonesSnap = await db.collection("zones_alea").get();

    for (const zoneDoc of zonesSnap.docs) {
      const zone = zoneDoc.data();
      try {
        const response = await axios.get(
          `https://api.open-meteo.com/v1/forecast?latitude=${zone.latitude}&longitude=${zone.longitude}&daily=precipitation_sum,temperature_2m_max&timezone=auto&forecast_days=1`
        );
        const daily = response.data.daily;
        const precipMm = daily.precipitation_sum?.[0] ?? 0;
        const tempMax = daily.temperature_2m_max?.[0] ?? 0;

        const typeAlerte = detecterAlerte(precipMm, tempMax);

        if (typeAlerte) {
          const message = messageAlerte(typeAlerte, zone.nom, precipMm, tempMax);

          // Notifier les utilisateurs avec un contrat actif dans cette zone
          const contratsSnap = await db
            .collection("contrats_assurance")
            .where("zone_risque", "==", zone.nom)
            .where("statut", "==", "actif")
            .get();

          const userIds = [...new Set(contratsSnap.docs.map((d) => d.data().userId))];

          for (const userId of userIds) {
            const userSnap = await db.collection("users").doc(userId).get();
            const fcmToken = userSnap.data()?.fcm_token;
            if (fcmToken) {
              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: `⚠️ Alerte ${typeAlerte} — ${zone.nom}`,
                  body: message,
                },
                data: { type: typeAlerte, zone: zone.nom },
              });
            }
          }
          functions.logger.info(`Alerte ${typeAlerte} envoyée pour zone ${zone.nom} (${userIds.length} utilisateurs).`);
        }
      } catch (err) {
        functions.logger.error(`Erreur vérification zone ${zone.nom}:`, err);
      }
    }
  });
