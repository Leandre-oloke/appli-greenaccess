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

// ── J2.7 — Module Assurance (contrats, sinistres, produits, zones aléas) ────

test('un utilisateur ne peut pas se déclarer admin dès la création de son profil', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(
    alice.doc('users/alice').set({ nom: 'Alice', role: 'admin' }),
  );
});

test('un utilisateur peut créer son propre contrat_assurance', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    alice.collection('contrats_assurance').add({ userId: 'alice', statut: 'actif' }),
  );
});

test("un contrat d'assurance est invisible pour un autre utilisateur", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('contrats_assurance/c1').set({ userId: 'alice', statut: 'actif' });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertFails(bob.doc('contrats_assurance/c1').get());
});

test('un partenaireAssureur peut lire et mettre à jour un contrat, le propriétaire ne peut pas le modifier', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('contrats_assurance/c1').set({ userId: 'alice', statut: 'actif' });
    await db.doc('users/assureur1').set({ nom: 'Assureur', role: 'partenaireAssureur' });
  });
  const assureur = testEnv.authenticatedContext('assureur1').firestore();
  await assertSucceeds(assureur.doc('contrats_assurance/c1').get());
  await assertSucceeds(assureur.doc('contrats_assurance/c1').update({ statut: 'resilie' }));

  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(alice.doc('contrats_assurance/c1').update({ statut: 'resilie' }));
});

test('un sinistre est invisible pour un autre utilisateur mais lisible par un partenaireAssureur', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('sinistres/s1').set({ userId: 'alice', statut: 'declare' });
    await db.doc('users/assureur1').set({ nom: 'Assureur', role: 'partenaireAssureur' });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertFails(bob.doc('sinistres/s1').get());
  const assureur = testEnv.authenticatedContext('assureur1').firestore();
  await assertSucceeds(assureur.doc('sinistres/s1').get());
});

test('produits_assurance : lecture ouverte, écriture réservée aux admins', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.doc('produits_assurance/p1').get());
  await assertFails(alice.doc('produits_assurance/p1').set({ nom: 'Produit' }));

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/admin1').set({ nom: 'Admin', role: 'admin' });
  });
  const admin = testEnv.authenticatedContext('admin1').firestore();
  await assertSucceeds(admin.doc('produits_assurance/p1').set({ nom: 'Produit' }));
});

test('zones_alea : lecture ouverte, écriture réservée aux admins', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.doc('zones_alea/z1').get());
  await assertFails(alice.doc('zones_alea/z1').set({ nom: 'Zone' }));
});

// ── J2.8 — Paiements, partenaires, notifications, remboursements ────────────

test('un paiement est invisible pour un autre utilisateur', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('paiements/pay1').set({ userId: 'alice', montant: 5000 });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(bob.doc('paiements/pay1').get());
  await assertSucceeds(alice.doc('paiements/pay1').get());
});

test('partenaires : lecture ouverte aux utilisateurs authentifiés, écriture réservée aux admins', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.doc('partenaires/pt1').get());
  await assertFails(alice.doc('partenaires/pt1').set({ nom: 'Partenaire' }));
});

test('notifications globales : un utilisateur ne peut ni créer ni supprimer, seul un admin le peut', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(alice.doc('notifications/n1').set({ titre: 'Alerte' }));

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/admin1').set({ nom: 'Admin', role: 'admin' });
  });
  const admin = testEnv.authenticatedContext('admin1').firestore();
  await assertSucceeds(admin.doc('notifications/n1').set({ titre: 'Alerte' }));
});

test('un utilisateur ne peut pas lire les échéances de remboursement de la demande d’un autre', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('demandes_financement/d1').set({ userId: 'alice', statut: 'approuve' });
    await db
      .doc('demandes_financement/d1/remboursements/e1')
      .set({ numero_echeance: 1, montant: 1000, paye: false });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(bob.doc('demandes_financement/d1/remboursements/e1').get());
  await assertSucceeds(alice.doc('demandes_financement/d1/remboursements/e1').get());
});

// ── Journal d'audit (J3.7) ─────────────────────────────────────────────────

test('un utilisateur peut créer un log d’audit pour sa propre action', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    alice.collection('audit_logs').add({
      userId: 'alice',
      action: 'financement_soumis',
      createdAt: new Date(),
    }),
  );
});

test('un utilisateur ne peut pas créer un log d’audit pour un autre userId', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(
    alice.collection('audit_logs').add({
      userId: 'bob',
      action: 'compte_supprime',
      createdAt: new Date(),
    }),
  );
});

test('un log d’audit sans les champs requis est refusé', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(alice.collection('audit_logs').add({ userId: 'alice' }));
});

test('un log d’audit ne peut jamais être modifié ni supprimé, même par un admin', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('audit_logs/log1').set({ userId: 'alice', action: 'paiement_initie', createdAt: new Date() });
    await db.doc('users/admin1').set({ nom: 'Admin', role: 'admin' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  const admin = testEnv.authenticatedContext('admin1').firestore();
  await assertFails(alice.doc('audit_logs/log1').update({ action: 'modifie' }));
  await assertFails(admin.doc('audit_logs/log1').update({ action: 'modifie' }));
  await assertFails(alice.doc('audit_logs/log1').delete());
  await assertFails(admin.doc('audit_logs/log1').delete());
});

test('seul un admin peut lire le journal d’audit', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('audit_logs/log1').set({ userId: 'alice', action: 'paiement_initie', createdAt: new Date() });
    await db.doc('users/admin1').set({ nom: 'Admin', role: 'admin' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  const admin = testEnv.authenticatedContext('admin1').firestore();
  await assertFails(alice.doc('audit_logs/log1').get());
  await assertSucceeds(admin.doc('audit_logs/log1').get());
});

// ── Messagerie liée à une demande de financement (J5.1-J5.2, restreinte J5.5) ─

test('le propriétaire d’une demande peut envoyer un message sur sa propre demande', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('demandes_financement/d1').set({ userId: 'alice', statut: 'soumis' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    alice.collection('demandes_financement/d1/messages').add({
      demande_id: 'd1',
      auteur_id: 'alice',
      auteur_nom: 'Alice',
      contenu: 'Bonjour',
      created_at: new Date(),
    }),
  );
});

test('un autre utilisateur ne peut ni lire ni écrire les messages d’une demande qui n’est pas la sienne', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('demandes_financement/d1').set({ userId: 'alice', statut: 'soumis' });
    await db.doc('demandes_financement/d1/messages/m1').set({
      demande_id: 'd1', auteur_id: 'alice', auteur_nom: 'Alice', contenu: 'x', created_at: new Date(),
    });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertFails(bob.doc('demandes_financement/d1/messages/m1').get());
  await assertFails(
    bob.collection('demandes_financement/d1/messages').add({
      demande_id: 'd1', auteur_id: 'bob', auteur_nom: 'Bob', contenu: 'intrusion', created_at: new Date(),
    }),
  );
});

test('le partenaire financeur spécifiquement assigné à la demande peut lire et écrire les messages', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('demandes_financement/d1').set({
      userId: 'alice', statut: 'soumis', partenaire_id: 'financeur1',
    });
  });
  const financeur = testEnv.authenticatedContext('financeur1').firestore();
  await assertSucceeds(financeur.doc('demandes_financement/d1').collection('messages').get());
  await assertSucceeds(
    financeur.collection('demandes_financement/d1/messages').add({
      demande_id: 'd1', auteur_id: 'financeur1', auteur_nom: 'Financeur', contenu: 'Réponse', created_at: new Date(),
    }),
  );
});

test('un partenaire financeur NON assigné à cette demande précise ne peut ni lire ni écrire ses messages', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('demandes_financement/d1').set({ userId: 'alice', statut: 'soumis', partenaire_id: 'financeur1' });
    await db.doc('demandes_financement/d1/messages/m1').set({
      demande_id: 'd1', auteur_id: 'alice', auteur_nom: 'Alice', contenu: 'x', created_at: new Date(),
    });
  });
  // financeur2 a bien le rôle partenaireFinanceur, mais n'est pas assigné à
  // CETTE demande — c'est exactement la restriction ajoutée en J5.5 (avant,
  // n'importe quel partenaireFinanceur pouvait accéder à n'importe quelle
  // conversation, pas seulement les deux parties concernées).
  const financeur2 = testEnv.authenticatedContext('financeur2').firestore();
  await assertFails(financeur2.doc('demandes_financement/d1/messages/m1').get());
  await assertFails(
    financeur2.collection('demandes_financement/d1/messages').add({
      demande_id: 'd1', auteur_id: 'financeur2', auteur_nom: 'Autre financeur', contenu: 'intrusion', created_at: new Date(),
    }),
  );
});

test('un utilisateur ne peut pas envoyer un message en usurpant l’identité d’un autre auteur', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('demandes_financement/d1').set({ userId: 'alice', statut: 'soumis' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(
    alice.collection('demandes_financement/d1/messages').add({
      demande_id: 'd1', auteur_id: 'admin1', auteur_nom: 'Admin', contenu: 'usurpation', created_at: new Date(),
    }),
  );
});

test('un admin peut lire et écrire les messages de n’importe quelle demande', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('demandes_financement/d1').set({ userId: 'alice', statut: 'soumis' });
    await db.doc('users/admin1').set({ nom: 'Admin', role: 'admin' });
  });
  const admin = testEnv.authenticatedContext('admin1').firestore();
  await assertSucceeds(
    admin.collection('demandes_financement/d1/messages').add({
      demande_id: 'd1', auteur_id: 'admin1', auteur_nom: 'Admin', contenu: 'Réponse admin', created_at: new Date(),
    }),
  );
});

test('un message ne peut jamais être modifié ni supprimé, même par son auteur ou un admin', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('demandes_financement/d1').set({ userId: 'alice', statut: 'soumis' });
    await db.doc('demandes_financement/d1/messages/m1').set({
      demande_id: 'd1', auteur_id: 'alice', auteur_nom: 'Alice', contenu: 'x', created_at: new Date(),
    });
    await db.doc('users/admin1').set({ nom: 'Admin', role: 'admin' });
  });
  const alice = testEnv.authenticatedContext('alice').firestore();
  const admin = testEnv.authenticatedContext('admin1').firestore();
  await assertFails(alice.doc('demandes_financement/d1/messages/m1').update({ contenu: 'modifié' }));
  await assertFails(admin.doc('demandes_financement/d1/messages/m1').update({ contenu: 'modifié' }));
  await assertFails(alice.doc('demandes_financement/d1/messages/m1').delete());
  await assertFails(admin.doc('demandes_financement/d1/messages/m1').delete());
});
