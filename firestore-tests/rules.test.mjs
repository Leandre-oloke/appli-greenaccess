// Tests des Firestore Security Rules (firestore.rules) contre l'émulateur
// Firestore, via la lib officielle @firebase/rules-unit-testing.
//
// Pourquoi Node.js et pas `flutter test` : un `flutter test` classique
// tourne dans la VM Dart sans platform channels, donc les plugins
// firebase_auth/cloud_firestore ne peuvent pas parler à un émulateur en
// cours d'exécution. @firebase/rules-unit-testing contourne le problème en
// synthétisant directement des contextes d'auth côté Node, sans avoir
// besoin d'un émulateur Auth. Voir README.md §7.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'greenaccess-rules-test',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8085,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

test('un utilisateur peut créer son propre document users/{uid}', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    alice.doc('users/alice').set({ nom: 'Alice', role: 'user' }),
  );
});

test("un utilisateur ne peut pas créer le document users/{uid} d'un autre", async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(
    alice.doc('users/bob').set({ nom: 'Usurpation', role: 'user' }),
  );
});

test('un utilisateur ne peut pas modifier son propre champ "role"', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/alice').set({ nom: 'Alice', role: 'user' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(alice.doc('users/alice').update({ role: 'admin' }));
});

test('un utilisateur peut modifier un champ non sensible de son propre profil', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/alice').set({ nom: 'Alice', role: 'user' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.doc('users/alice').update({ nom: 'Alice Dupont' }));
});

test("un admin peut lire le profil d'un autre utilisateur", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('users/alice').set({ nom: 'Alice', role: 'user' });
    await db.doc('users/admin1').set({ nom: 'Admin', role: 'admin' });
  });
  const admin = testEnv.authenticatedContext('admin1').firestore();
  await assertSucceeds(admin.doc('users/alice').get());
});

test('un utilisateur ne peut pas lire le profil d’un autre utilisateur', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('users/alice').set({ nom: 'Alice', role: 'user' });
    await db.doc('users/bob').set({ nom: 'Bob', role: 'user' });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertFails(bob.doc('users/alice').get());
});

test('un utilisateur peut créer un score_climat pour lui-même', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    alice.collection('scores_climat').add({ userId: 'alice', score: 72 }),
  );
});

test('un utilisateur ne peut pas créer un score_climat pour un autre userId', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(
    alice.collection('scores_climat').add({ userId: 'bob', score: 72 }),
  );
});

test('une demande de financement est invisible pour un autre utilisateur', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc('demandes_financement/d1')
      .set({ userId: 'alice', statut: 'brouillon', montant: 1000 });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(bob.doc('demandes_financement/d1').get());
  await assertSucceeds(alice.doc('demandes_financement/d1').get());
});

test('un partenaireFinanceur peut mettre à jour une demande de financement', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db
      .doc('demandes_financement/d1')
      .set({ userId: 'alice', statut: 'brouillon', montant: 1000 });
    await db.doc('users/financeur1').set({ nom: 'Financeur', role: 'partenaireFinanceur' });
  });
  const financeur = testEnv.authenticatedContext('financeur1').firestore();
  await assertSucceeds(
    financeur.doc('demandes_financement/d1').update({ statut: 'approuvee' }),
  );
});

test('un utilisateur non authentifié ne peut rien lire', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/alice').set({ nom: 'Alice', role: 'user' });
  });
  const anon = testEnv.unauthenticatedContext().firestore();
  await assertFails(anon.doc('users/alice').get());
});
