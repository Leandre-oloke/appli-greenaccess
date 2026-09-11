// Initialise `firebase-functions-test` en mode "offline" (aucun projet GCP
// réel requis) — infrastructure prête pour tester de futures Cloud
// Functions déclenchées (onCourseCompleted, onDemandeSubmitted…) via
// `wrap()`/`makeChange()`, en plus des tests de fonctions pures déjà
// présents (calculerScoreClimat.test.ts).
//
// GCLOUD_PROJECT doit être défini AVANT d'importer src/index.ts : ce fichier
// appelle admin.initializeApp() à son chargement, qui a besoin de pouvoir
// déterminer un projet — sans émulateur ni service account (contexte Node
// nu), ça échouerait sinon. Voir README.md §7.
process.env.GCLOUD_PROJECT ??= "demo-greenaccess-test";

import functionsTest from "firebase-functions-test";

export const testEnv = functionsTest();
