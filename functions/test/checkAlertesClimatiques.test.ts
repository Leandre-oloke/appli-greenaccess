// Tests de checkAlertesClimatiques (fonction planifiée). Regroupe deux
// niveaux de couverture :
// - detecterAlerte() : fonction pure extraite (seuils sécheresse/inondation/
//   chaleur), testée directement, sans réseau ni Firestore.
// - checkAlertesClimatiques bout en bout, avec axios.get mocké (via
//   t.mock.method — un import par défaut comme `import axios from "axios"`
//   pointe vers un objet CJS mutable, contrairement à `import * as admin
//   from "firebase-admin"` dont le namespace est figé et non mockable, voir
//   README.md §7) : lit vraiment `zones_alea` sur l'émulateur Firestore, mais
//   n'atteint jamais admin.messaging() — aucun test ne seed de contrat actif
//   dans la zone concernée, donc la boucle de notification reste vide (il
//   n'existe pas d'émulateur FCM dans la Firebase Emulator Suite).
// Nécessite l'émulateur Firestore : voir functions/test/triggers.test.ts et
// package.json ("test:emulator").
import { testEnv } from "./testEnv";
import { test } from "node:test";
import assert from "node:assert/strict";
import axios from "axios";
import * as admin from "firebase-admin";
import { detecterAlerte, checkAlertesClimatiques } from "../src/index";

const db = admin.firestore();
const wrapped = testEnv.wrap(checkAlertesClimatiques);

async function clearCollection(path: string) {
  const snap = await db.collection(path).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

// ── J2.15 — Seuils purs (aucun réseau, aucun émulateur nécessaire) ─────────

test("detecterAlerte : sécheresse (peu de pluie + forte chaleur)", () => {
  assert.equal(detecterAlerte(1, 36), "secheresse");
  assert.equal(detecterAlerte(0, 38), "secheresse");
});

test("detecterAlerte : inondation (fortes précipitations)", () => {
  assert.equal(detecterAlerte(81, 20), "inondation");
});

test("detecterAlerte : chaleur extrême", () => {
  assert.equal(detecterAlerte(10, 41), "chaleur");
});

test("detecterAlerte : rien si sous tous les seuils, y compris pile sur les bornes", () => {
  assert.equal(detecterAlerte(10, 30), null);
  assert.equal(detecterAlerte(2, 35), null); // bornes strictes (< / >), pile dessus = pas déclenché
  assert.equal(detecterAlerte(80, 40), null);
});

test("detecterAlerte : priorité inondation > chaleur > sécheresse en cas de cumul", () => {
  assert.equal(detecterAlerte(90, 42), "inondation"); // inondation + chaleur → inondation gagne
  assert.equal(detecterAlerte(1, 41), "chaleur"); // sécheresse + chaleur → chaleur gagne
});

// ── J2.15 — Open-Meteo mocké, bout en bout via la fonction planifiée ───────

test(
  "checkAlertesClimatiques appelle Open-Meteo avec les coordonnées de la zone et détecte une inondation",
  async (t) => {
    await clearCollection("zones_alea");
    await clearCollection("contrats_assurance");
    await db.collection("zones_alea").doc("z1").set({
      nom: "Vallée du Fleuve",
      latitude: 16.5,
      longitude: -15.5,
    });

    let calledUrl = "";
    t.mock.method(axios, "get", async (url: string) => {
      calledUrl = url;
      return { data: { daily: { precipitation_sum: [95], temperature_2m_max: [28] } } };
    });

    // Aucun contrat actif dans cette zone : la boucle de notification reste
    // vide, admin.messaging() n'est jamais atteint (voir en-tête de fichier).
    await assert.doesNotReject(wrapped());

    assert.match(calledUrl, /api\.open-meteo\.com/);
    assert.match(calledUrl, /latitude=16\.5/);
    assert.match(calledUrl, /longitude=-15\.5/);
  },
);

test("checkAlertesClimatiques ne lève aucune erreur pour une zone sans aléa détecté", async (t) => {
  await clearCollection("zones_alea");
  await db.collection("zones_alea").doc("z2").set({ nom: "Zone calme", latitude: 12.0, longitude: -1.0 });

  t.mock.method(axios, "get", async () => ({
    data: { daily: { precipitation_sum: [10], temperature_2m_max: [30] } },
  }));

  await assert.doesNotReject(wrapped());
});

test("checkAlertesClimatiques continue sur les autres zones si Open-Meteo échoue pour l'une d'elles", async (t) => {
  await clearCollection("zones_alea");
  await db.collection("zones_alea").doc("z3").set({ nom: "Zone A", latitude: 0, longitude: 0 });
  await db.collection("zones_alea").doc("z4").set({ nom: "Zone B", latitude: 1, longitude: 1 });

  let calls = 0;
  t.mock.method(axios, "get", async () => {
    calls += 1;
    if (calls === 1) throw new Error("Timeout réseau simulé");
    return { data: { daily: { precipitation_sum: [0], temperature_2m_max: [20] } } };
  });

  // La zone en erreur est catch()ée individuellement (try/catch par zone
  // dans checkAlertesClimatiques) — la fonction entière ne doit pas planter.
  await assert.doesNotReject(wrapped());
  assert.equal(calls, 2); // la 2e zone a bien été traitée malgré l'échec de la 1re
});
