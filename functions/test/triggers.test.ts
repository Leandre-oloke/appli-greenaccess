// Tests des Cloud Functions déclenchées par Firestore (onCourseCompleted,
// onDemandeSubmitted) — contrairement à calculerScoreClimat.test.ts, ces
// fonctions font de vraies lectures/écritures Firestore (via `db =
// admin.firestore()` dans src/index.ts) : il faut donc l'émulateur Firestore
// démarré. Exécuté via `npm --prefix functions run test:emulator`, à
// l'intérieur de `firebase emulators:exec --only firestore` (voir
// .github/workflows/ci.yml, job "backend tests").
//
// onDemandeSubmitted appelle admin.messaging() s'il y a des destinataires —
// il n'existe pas d'émulateur FCM dans la Firebase Emulator Suite, un vrai
// appel contacterait un serveur Google. On ne teste donc jamais un scénario
// où ça arrive : soit aucun partenaire n'a de token (branche jamais prise),
// soit on teste directement getPartenaireFinanceurTokens(), extraite pour
// être vérifiable sans jamais toucher admin.messaging(). Voir src/index.ts.
import { testEnv } from "./testEnv";
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import * as admin from "firebase-admin";
import {
  onCourseCompleted,
  onDemandeSubmitted,
  getPartenaireFinanceurTokens,
} from "../src/index";

const db = admin.firestore();
const wrappedOnCourseCompleted = testEnv.wrap(onCourseCompleted);
const wrappedOnDemandeSubmitted = testEnv.wrap(onDemandeSubmitted);

// Nettoie entre les tests pour éviter qu'un document d'un test précédent
// (même collection, ids fixes) ne fausse une assertion.
async function clearCollection(path: string) {
  const snap = await db.collection(path).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

before(async () => {
  await clearCollection("courses");
  await clearCollection("demandes_financement");
  await clearCollection("users");
});

after(async () => {
  await testEnv.cleanup();
});

// ── J2.13 — onCourseCompleted : badge déclenché + idempotence ──────────────

test("onCourseCompleted crée le badge défini par le cours quand il est déclenché", async () => {
  await db.collection("courses").doc("course1").set({ badge_id: "badge-course1" });

  const before_ = testEnv.firestore.makeDocumentSnapshot(
    { statut: "EN_COURS" },
    "users/alice/progress/course1",
  );
  const after_ = testEnv.firestore.makeDocumentSnapshot(
    { statut: "TERMINE", badge_declenche: true, score_quiz: 85 },
    "users/alice/progress/course1",
  );
  const change = testEnv.makeChange(before_, after_);

  await wrappedOnCourseCompleted(change, { params: { userId: "alice", courseId: "course1" } });

  const badgeSnap = await db.collection("users").doc("alice").collection("badges").doc("badge-course1").get();
  assert.equal(badgeSnap.exists, true);
  assert.equal(badgeSnap.data()?.courseId, "course1");
});

test("onCourseCompleted est idempotent : un deuxième déclenchement ne recrée pas le badge", async () => {
  await db.collection("courses").doc("course2").set({ badge_id: "badge-course2" });

  const after_ = testEnv.firestore.makeDocumentSnapshot(
    { statut: "TERMINE", badge_declenche: true, score_quiz: 90 },
    "users/bob/progress/course2",
  );
  const change = testEnv.makeChange(
    testEnv.firestore.makeDocumentSnapshot({ statut: "EN_COURS" }, "users/bob/progress/course2"),
    after_,
  );
  const context = { params: { userId: "bob", courseId: "course2" } };

  await wrappedOnCourseCompleted(change, context);
  const badgeRef = db.collection("users").doc("bob").collection("badges").doc("badge-course2");
  const firstSnap = await badgeRef.get();
  const firstDate = firstSnap.data()?.dateObtention;
  assert.ok(firstDate, "dateObtention doit être renseignée après le premier déclenchement");

  // Deuxième déclenchement (ex. re-write du même document de progression) :
  // ne doit pas écraser le badge existant.
  await wrappedOnCourseCompleted(testEnv.makeChange(after_, after_), context);
  const secondSnap = await badgeRef.get();
  assert.deepEqual(secondSnap.data()?.dateObtention, firstDate);
});

test("onCourseCompleted ne crée aucun badge si le cours n'en définit pas", async () => {
  await db.collection("courses").doc("course3").set({}); // pas de badge_id

  const after_ = testEnv.firestore.makeDocumentSnapshot(
    { statut: "TERMINE", badge_declenche: true },
    "users/carol/progress/course3",
  );
  await wrappedOnCourseCompleted(
    testEnv.makeChange(testEnv.firestore.makeDocumentSnapshot({}, "users/carol/progress/course3"), after_),
    { params: { userId: "carol", courseId: "course3" } },
  );

  const badgesSnap = await db.collection("users").doc("carol").collection("badges").get();
  assert.equal(badgesSnap.empty, true);
});

test("onCourseCompleted ne fait rien si le cours n'est pas terminé", async () => {
  await db.collection("courses").doc("course4").set({ badge_id: "badge-course4" });

  const after_ = testEnv.firestore.makeDocumentSnapshot(
    { statut: "EN_COURS" },
    "users/dave/progress/course4",
  );
  await wrappedOnCourseCompleted(
    testEnv.makeChange(testEnv.firestore.makeDocumentSnapshot({}, "users/dave/progress/course4"), after_),
    { params: { userId: "dave", courseId: "course4" } },
  );

  const badgeSnap = await db.collection("users").doc("dave").collection("badges").doc("badge-course4").get();
  assert.equal(badgeSnap.exists, false);
});

// ── J2.14 — onDemandeSubmitted : notification aux partenaires financeurs ───

test("getPartenaireFinanceurTokens ne renvoie que les partenaireFinanceur ayant un token FCM", async () => {
  await db.collection("users").doc("financeur1").set({ role: "partenaireFinanceur", fcm_token: "tok-financeur-1" });
  await db.collection("users").doc("financeur2").set({ role: "partenaireFinanceur" }); // pas de token
  await db.collection("users").doc("alice").set({ role: "user", fcm_token: "tok-alice" });
  await db.collection("users").doc("assureur1").set({ role: "partenaireAssureur", fcm_token: "tok-assureur" });

  const tokens = await getPartenaireFinanceurTokens();
  assert.deepEqual(tokens, ["tok-financeur-1"]);
});

test("onDemandeSubmitted se déclenche sans erreur pour une demande soumise (aucun partenaire à notifier)", async () => {
  await clearCollection("users"); // aucun partenaireFinanceur → tokens.length === 0, messaging() jamais appelé
  const snap = testEnv.firestore.makeDocumentSnapshot(
    { userId: "alice", statut: "soumis", montant: 500000, type_projet: "Agriculture", pays: "Sénégal" },
    "demandes_financement/d1",
  );

  await assert.doesNotReject(
    wrappedOnDemandeSubmitted(snap, { params: { demandeId: "d1" } }),
  );
});

test("onDemandeSubmitted ne fait rien pour une demande encore en brouillon", async () => {
  const snap = testEnv.firestore.makeDocumentSnapshot(
    { userId: "alice", statut: "brouillon", montant: 500000 },
    "demandes_financement/d2",
  );

  await assert.doesNotReject(
    wrappedOnDemandeSubmitted(snap, { params: { demandeId: "d2" } }),
  );
});
