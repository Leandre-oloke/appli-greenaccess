// Tests unitaires purs de la formule de calculerScoreClimat — sans
// émulateur, sans réseau (contrairement à firestore-tests/ et à
// integration_test/score_repository_test.dart qui exercent le vrai appel
// callable). But : verrouiller la formule pondérée (J2.10) et garantir un
// score toujours valide, bornes + arrondi (J2.11). Exécuté via
// `npm --prefix functions test` (node --test + tsx, voir package.json).
//
// L'ordre des imports compte : ./testEnv doit être évalué avant src/index
// (qui appelle admin.initializeApp() à son chargement) pour que GCLOUD_PROJECT
// soit déjà défini — voir le commentaire dans testEnv.ts.
import "./testEnv";
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  calculerScore,
  co2ToScore,
  certifToScore,
  resilienceToScore,
  type ScoreCriteres,
} from "../src/index";

const criteres = (overrides: Partial<ScoreCriteres> = {}): ScoreCriteres => ({
  scoreActivite: 0,
  scoreUemoa: 0,
  scoreCo2: 0,
  scoreCertif: 0,
  scoreResilience: 0,
  bonusFormation: 0,
  ...overrides,
});

// ── J2.10 — Formule pondérée exacte ─────────────────────────────────────────
// Score = (Activité×0.25) + (UEMOA×0.20) + (CO2×0.20) + (Certif×0.20) + (Résilience×0.15) + BonusFormation

test('calculerScore applique exactement les poids 0.25/0.20/0.20/0.20/0.15 du CDC', () => {
  const score = calculerScore(
    criteres({
      scoreActivite: 80,
      scoreUemoa: 100,
      scoreCo2: 60,
      scoreCertif: 50,
      scoreResilience: 80,
      bonusFormation: 5,
    }),
  );
  // 80×0.25 + 100×0.20 + 60×0.20 + 50×0.20 + 80×0.15 + 5
  // = 20 + 20 + 12 + 10 + 12 + 5 = 79
  assert.equal(score, 79);
});

test('chaque critère pèse isolément le poids attendu (un seul critère non nul à la fois)', () => {
  assert.equal(calculerScore(criteres({ scoreActivite: 100 })), 25);
  assert.equal(calculerScore(criteres({ scoreUemoa: 100 })), 20);
  assert.equal(calculerScore(criteres({ scoreCo2: 100 })), 20);
  assert.equal(calculerScore(criteres({ scoreCertif: 100 })), 20);
  assert.equal(calculerScore(criteres({ scoreResilience: 100 })), 15);
});

test('bonusFormation s\'ajoute intégralement, sans pondération', () => {
  assert.equal(calculerScore(criteres({ bonusFormation: 7 })), 7);
});

test('co2ToScore respecte les paliers du CDC (0/20/40/60/80/100)', () => {
  assert.equal(co2ToScore(0), 0);
  assert.equal(co2ToScore(1), 20);
  assert.equal(co2ToScore(49), 20);
  assert.equal(co2ToScore(50), 40);
  assert.equal(co2ToScore(99), 40);
  assert.equal(co2ToScore(100), 60);
  assert.equal(co2ToScore(199), 60);
  assert.equal(co2ToScore(200), 80);
  assert.equal(co2ToScore(499), 80);
  assert.equal(co2ToScore(500), 100);
  assert.equal(co2ToScore(10_000), 100);
});

test('certifToScore additionne les certifications sélectionnées', () => {
  assert.equal(certifToScore(['Bio']), 25);
  assert.equal(certifToScore(['Bio', 'ISO 14001']), 55);
  assert.equal(certifToScore([]), 0);
  assert.equal(certifToScore(['Certification inconnue']), 0);
});

test('resilienceToScore multiplie par 20 (échelle 1-5 → 0-100)', () => {
  assert.equal(resilienceToScore(1), 20);
  assert.equal(resilienceToScore(3), 60);
  assert.equal(resilienceToScore(5), 100);
});

// ── J2.11 — Bornes 0-100 et arrondi ─────────────────────────────────────────

test('calculerScore ne dépasse jamais 100, même avec tous les critères au maximum', () => {
  const score = calculerScore(
    criteres({
      scoreActivite: 100,
      scoreUemoa: 100,
      scoreCo2: 100,
      scoreCertif: 100,
      scoreResilience: 100,
      bonusFormation: 15, // max théorique du bonus formation
    }),
  );
  // Brut = 25+20+20+20+15+15 = 115, doit être plafonné à 100
  assert.equal(score, 100);
});

test('calculerScore reste à 0 quand tous les critères sont nuls', () => {
  assert.equal(calculerScore(criteres()), 0);
});

test('calculerScore ne devient jamais négatif, même avec un critère hors plage (résilience négative)', () => {
  // Un client qui n'aurait pas respecté la plage 1-5 (bug, appel direct de
  // l'API, ancienne version de l'app…) ne doit jamais produire un score
  // négatif écrit en base.
  const scoreResilience = resilienceToScore(-10); // aurait été -200 sans le clamp bas
  assert.equal(scoreResilience, 0);
  assert.equal(calculerScore(criteres({ scoreResilience })), 0);
});

test('certifToScore et resilienceToScore restent dans [0, 100] même avec une entrée aberrante', () => {
  assert.equal(resilienceToScore(-3), 0);
  assert.equal(resilienceToScore(1000), 100);
  assert.equal(certifToScore(['Bio', 'ISO 14001', 'Carbone Neutre', 'Équitable']), 100); // 25+30+25+20=100, pas plus
});

test('calculerScore arrondit correctement à 1 décimale (JS arrondit .5 vers le haut)', () => {
  const score = calculerScore(
    criteres({
      scoreActivite: 75, // ×0.25 = 18.75
      scoreUemoa: 60, // ×0.20 = 12
      scoreCo2: 20, // ×0.20 = 4
      scoreCertif: 25, // ×0.20 = 5
      scoreResilience: 60, // ×0.15 = 9
      bonusFormation: 2,
    }),
  );
  // 18.75+12+4+5+9+2 = 50.75 → ×10=507.5 → round=508 → /10 = 50.8
  assert.equal(score, 50.8);
});
