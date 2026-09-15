// E2E T05 (J6.4, CDC §7.2 · T05) : parcours complet de dépôt d'une demande
// de financement (formulaire à 7 étapes) jusqu'au statut SOUMIS, avec un
// partenaire financeur en mesure d'être notifié.
//
// La séquence de navigation du formulaire (7 étapes, champs requis
// uniquement à l'étape 2, case de confirmation à l'étape 7) reprend
// exactement celle déjà éprouvée par
// test/widgets/demande_form_screen_test.dart — même parcours, piloté ici sur
// un appareil réel plutôt qu'en isolation.
//
// « + notification partenaire » (CDC) : un partenaire financeur
// (`role: partenaireFinanceur`) est semé avant la soumission — c'est la
// précondition que le déclencheur `onDemandeSubmitted` (Cloud Function)
// utilise pour cibler qui notifier (`getPartenaireFinanceurTokens()`).
// L'émulateur Functions n'est volontairement PAS démarré ici (ni le
// partenaire semé avec un `fcm_token`) : il n'existe pas d'émulateur FCM
// dans la Firebase Emulator Suite, un envoi réel contacterait de vrais
// serveurs Google — exactement la même contrainte que
// functions/test/triggers.test.ts (voir README.md §7). Le ciblage des
// partenaires à notifier est déjà validé à ce niveau (2 tests dédiés,
// `getPartenaireFinanceurTokens`) ; ce scénario E2E valide ce que lui seul
// peut valider : le dépôt réel d'une demande, à travers la vraie UI,
// jusqu'au statut SOUMIS persistant réellement en base.
//
// Non exécutable dans ce Codespace (aucun émulateur/adb, voir README.md §7).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:greenaccess/main.dart' as app;
import 'package:greenaccess/models/score_climat_model.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/score_repository.dart';

import 'helpers/e2e_helpers.dart';

void main() {
  patrolTest(
    'T05 — dépôt complet d\'une demande de financement jusqu\'au statut SOUMIS',
    ($) async {
      await app.main();
      await $.pumpAndSettle();

      final email = uniqueEmail('e2e-t05');
      const password = 'GreenAccessE2E1!';

      // Arrange : demandeur éligible (score 75, ≥ 60) + un partenaire
      // financeur existant (précondition de notification, voir en-tête).
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;
      await AuthRepository().saveUserProfile(UserModel(
        id: uid,
        nom: 'E2E T05',
        email: email,
        telephone: '',
        pays: 'Sénégal',
        region: 'Dakar',
        secteur: 'Agriculture',
        dateInscription: DateTime.now(),
        profilComplet: true,
        role: UserRole.user,
      ));
      await ScoreRepository().saveScore(
        uid,
        ScoreClimatModel(
          id: '',
          userId: uid,
          scoreTotal: 75,
          criteres: const ScoreCriteres(
            scoreActivite: 75,
            scoreUemoa: 60,
            scoreCo2: 80,
            scoreCertif: 50,
            scoreResilience: 80,
            bonusFormation: 0,
          ),
          niveau: NiveauScore.bon,
          suggestions: const [],
          dateCalcul: DateTime.now(),
          versionAlgo: 'v1-e2e-seed',
        ),
      );
      await FirebaseFirestore.instance.collection('users').doc('e2e-t05-partenaire').set({
        'nom': 'Partenaire E2E T05',
        'email': 'partenaire-e2e-t05@greenaccess.test',
        'telephone': '',
        'pays': 'Sénégal',
        'region': '',
        'secteur': '',
        'date_inscription': FieldValue.serverTimestamp(),
        'profil_complet': true,
        'role': 'partenaireFinanceur',
        // Pas de fcm_token : voir en-tête de fichier — aucun envoi FCM réel
        // n'est déclenché ici, seule la précondition de ciblage est semée.
      });
      await FirebaseAuth.instance.signOut();

      await skipOnboardingToLogin($);

      // Act : connexion, puis dépôt de la demande à travers le vrai parcours UI.
      await $(TextFormField).at(0).enterText(email);
      await $(TextFormField).at(1).enterText(password);
      await $('Se connecter').tap();
      await $.pumpAndSettle();
      expect($('Accès rapide'), findsOneWidget);

      await $('Financement').at(0).tap();
      await $.pumpAndSettle();
      expect($('Éligible au financement'), findsOneWidget);

      await $('Nouvelle demande').tap();
      await $.pumpAndSettle();
      expect($('Étape 1 / 7'), findsOneWidget);

      // Étape 1 : profil déjà pré-rempli (nom, pays, région, secteur).
      await $(ElevatedButton).tap();
      await $.pumpAndSettle();
      expect($('Étape 2 / 7'), findsOneWidget);

      // Étape 2 : seuls champs requis du formulaire.
      await $(TextFormField).at(0).enterText('Maraîchage solaire — E2E T05');
      await $(TextFormField).at(1).enterText(
            'Extension d\'une exploitation maraîchère biologique avec irrigation solaire, '
            'scénario E2E T05.',
          );
      await $(ElevatedButton).tap();
      await $.pumpAndSettle();
      expect($('Étape 3 / 7'), findsOneWidget);

      // Étapes 3-6 : aucun champ requis, valeurs par défaut acceptées.
      for (final titre in ['Étape 4 / 7', 'Étape 5 / 7', 'Étape 6 / 7', 'Étape 7 / 7']) {
        await $(ElevatedButton).tap();
        await $.pumpAndSettle();
        expect($(titre), findsOneWidget);
      }

      // Étape 7 : case de confirmation puis soumission.
      await $(CheckboxListTile).tap();
      await $('Soumettre la demande').tap();
      await $.pumpAndSettle();

      // Assert : retour à FinancementScreen (context.pop() après soumission),
      // ET statut réellement persistant à SOUMIS côté Firestore — vérification
      // directe plutôt que dépendante d'un libellé d'écran précis.
      expect($('Éligible au financement'), findsOneWidget);

      final demandes = await FirebaseFirestore.instance
          .collection('demandes_financement')
          .where('userId', isEqualTo: uid)
          .get();
      expect(demandes.docs, hasLength(1));
      expect(demandes.docs.first.data()['statut'], 'soumis');
    },
  );
}
