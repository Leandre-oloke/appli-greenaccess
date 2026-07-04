"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkAlertesClimatiques = exports.onDemandeSubmitted = exports.onCourseCompleted = exports.calculerScoreClimat = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const axios_1 = __importDefault(require("axios"));
admin.initializeApp();
const db = admin.firestore();
// ── Constantes métier ────────────────────────────────────────────────────────
const SCORE_ACTIVITE_MAP = {
    Agriculture: 75,
    "Énergie renouvelable": 90,
    Recyclage: 85,
    "Transport propre": 80,
    "Forêt / Agroforesterie": 88,
    "Pêche durable": 70,
    Autre: 50,
};
const SCORE_CERTIF_MAP = {
    "Agriculture biologique": 25,
    "Commerce équitable": 20,
    "ISO 14001": 30,
    "Carbone Neutre": 25,
};
const UEMOA_SCORE_MAP = {
    Oui: 100,
    Partiel: 60,
    Non: 20,
};
/**
 * Calcule le Score Climat ESG selon la formule du CDC :
 * Score = (Activité×0.25) + (UEMOA×0.20) + (CO2×0.20) + (Certif×0.20) + (Résilience×0.15) + BonusFormation
 */
function calculerScore(input) {
    const score = input.scoreActivite * 0.25 +
        input.scoreUemoa * 0.20 +
        input.scoreCo2 * 0.20 +
        input.scoreCertif * 0.20 +
        input.scoreResilience * 0.15 +
        input.bonusFormation;
    return Math.min(100, Math.round(score * 10) / 10);
}
function co2ToScore(reductionCo2) {
    if (reductionCo2 >= 500)
        return 100;
    if (reductionCo2 >= 200)
        return 80;
    if (reductionCo2 >= 100)
        return 60;
    if (reductionCo2 >= 50)
        return 40;
    if (reductionCo2 > 0)
        return 20;
    return 0;
}
function certifToScore(certifications) {
    const total = certifications.reduce((sum, c) => { var _a; return sum + ((_a = SCORE_CERTIF_MAP[c]) !== null && _a !== void 0 ? _a : 0); }, 0);
    return Math.min(100, total);
}
function resilienceToScore(resilience) {
    return Math.min(100, resilience * 20);
}
async function getBonusFormation(userId) {
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
function determineNiveau(score) {
    if (score >= 80)
        return "excellent";
    if (score >= 60)
        return "bon";
    if (score >= 40)
        return "intermediaire";
    return "insuffisant";
}
function genererSuggestions(input, scoreTotal) {
    const suggestions = [];
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
exports.calculerScoreClimat = functions
    .region("europe-west1")
    .https.onCall(async (data, context) => {
    var _a, _b;
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentification requise.");
    }
    if (context.auth.uid !== data.userId) {
        throw new functions.https.HttpsError("permission-denied", "Accès non autorisé.");
    }
    const bonusFormation = await getBonusFormation(data.userId);
    const criteres = {
        scoreActivite: (_a = SCORE_ACTIVITE_MAP[data.typeActivite]) !== null && _a !== void 0 ? _a : 50,
        scoreUemoa: (_b = UEMOA_SCORE_MAP[data.alignementUemoa]) !== null && _b !== void 0 ? _b : 20,
        scoreCo2: co2ToScore(data.reductionCo2),
        scoreCertif: certifToScore(data.certifications),
        scoreResilience: resilienceToScore(data.resilience),
        bonusFormation,
    };
    const scoreTotal = calculerScore(criteres);
    const niveau = determineNiveau(scoreTotal);
    const suggestions = genererSuggestions(criteres, scoreTotal);
    const scoreDoc = {
        userId: data.userId,
        scoreTotal,
        criteres: {
            score_activite: criteres.scoreActivite,
            score_uemoa: criteres.scoreUemoa,
            score_co2: criteres.scoreCo2,
            score_certif: criteres.scoreCertif,
            score_resilience: criteres.scoreResilience,
            bonus_formation: criteres.bonusFormation,
        },
        niveau,
        suggestions,
        dateCalcul: admin.firestore.FieldValue.serverTimestamp(),
        versionAlgo: "1.0.0",
    };
    const docRef = await db.collection("scores_climat").add(scoreDoc);
    return { scoreId: docRef.id, scoreTotal, niveau, suggestions };
});
// ── Cloud Function : onCourseCompleted ───────────────────────────────────────
exports.onCourseCompleted = functions
    .region("europe-west1")
    .firestore.document("users/{userId}/progress/{courseId}")
    .onWrite(async (change, context) => {
    const after = change.after.data();
    if (!after || after.statut !== "TERMINE")
        return;
    const { userId, courseId } = context.params;
    // Récupérer les infos du cours
    const courseSnap = await db.collection("courses").doc(courseId).get();
    const course = courseSnap.data();
    if (!course)
        return;
    // Déclencher badge si défini
    if (course.badge_id && after.badge_declenche) {
        const badgeRef = db.collection("users").doc(userId).collection("badges").doc(course.badge_id);
        const badgeSnap = await badgeRef.get();
        if (!badgeSnap.exists) {
            await badgeRef.set({
                dateObtention: admin.firestore.FieldValue.serverTimestamp(),
                courseId,
                openbadge_url: null,
            });
            // TODO: appel OpenBadge Factory API pour émettre le badge certifié
            functions.logger.info(`Badge ${course.badge_id} déclenché pour ${userId}`);
        }
    }
});
// ── Cloud Function : onDemandeSubmitted ──────────────────────────────────────
exports.onDemandeSubmitted = functions
    .region("europe-west1")
    .firestore.document("demandes_financement/{demandeId}")
    .onCreate(async (snap, context) => {
    const demande = snap.data();
    if (!demande || demande.statut !== "soumis")
        return;
    // Notifier les partenaires financeurs éligibles (FCM)
    const partenairesSnap = await db
        .collection("users")
        .where("role", "==", "partenaireFinanceur")
        .get();
    const tokens = [];
    partenairesSnap.forEach((doc) => {
        if (doc.data().fcm_token)
            tokens.push(doc.data().fcm_token);
    });
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
// ── Cloud Function : onAlertClimatique (schedulée) ───────────────────────────
exports.checkAlertesClimatiques = functions
    .region("europe-west1")
    .pubsub.schedule("every 24 hours")
    .onRun(async () => {
    var _a, _b, _c, _d, _e;
    // Vérifier les alertes météo via API publique (OpenMeteo)
    const zonesSnap = await db.collection("zones_alea").get();
    for (const zoneDoc of zonesSnap.docs) {
        const zone = zoneDoc.data();
        try {
            const response = await axios_1.default.get(`https://api.open-meteo.com/v1/forecast?latitude=${zone.latitude}&longitude=${zone.longitude}&daily=precipitation_sum,temperature_2m_max&timezone=auto&forecast_days=1`);
            const daily = response.data.daily;
            const precipMm = (_b = (_a = daily.precipitation_sum) === null || _a === void 0 ? void 0 : _a[0]) !== null && _b !== void 0 ? _b : 0;
            const tempMax = (_d = (_c = daily.temperature_2m_max) === null || _c === void 0 ? void 0 : _c[0]) !== null && _d !== void 0 ? _d : 0;
            const isSecheresse = precipMm < 2 && tempMax > 35;
            const isInondation = precipMm > 80;
            const isChaleur = tempMax > 40;
            if (isSecheresse || isInondation || isChaleur) {
                const typeAlerte = isInondation ? "inondation" : isChaleur ? "chaleur" : "secheresse";
                const message = isInondation
                    ? `Alerte inondation : ${precipMm}mm prévus dans la zone ${zone.nom}`
                    : isChaleur
                        ? `Alerte chaleur extrême : ${tempMax}°C prévus dans la zone ${zone.nom}`
                        : `Alerte sécheresse : précipitations insuffisantes dans la zone ${zone.nom}`;
                // Notifier les utilisateurs avec un contrat actif dans cette zone
                const contratsSnap = await db
                    .collection("contrats_assurance")
                    .where("zone_risque", "==", zone.nom)
                    .where("statut", "==", "actif")
                    .get();
                const userIds = [...new Set(contratsSnap.docs.map((d) => d.data().userId))];
                for (const userId of userIds) {
                    const userSnap = await db.collection("users").doc(userId).get();
                    const fcmToken = (_e = userSnap.data()) === null || _e === void 0 ? void 0 : _e.fcm_token;
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
        }
        catch (err) {
            functions.logger.error(`Erreur vérification zone ${zone.nom}:`, err);
        }
    }
});
//# sourceMappingURL=index.js.map