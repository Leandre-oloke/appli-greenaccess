// E2E T07 (J6.5, CDC §7.2 · T07) : un cours déjà consulté en ligne reste
// utilisable hors-ligne (contenu servi depuis le cache Firestore local), un
// quiz peut y être complété hors-ligne, et la progression se synchronise
// réellement au retour du réseau.
//
// Persistance Firestore : désactivée par défaut avec les émulateurs (voir
// lib/main.dart, kUseEmulator) pour éviter un cache périmé entre deux
// redémarrages d'émulateur en dev — hors de propos pour ce run E2E isolé, où
// l'émulateur démarre une seule fois. Ce scénario a donc besoin du flag dédié
// FORCE_PERSISTENCE=true (voir .github/workflows/e2e.yml), sans quoi le
// contenu ne survivrait jamais au passage hors-ligne — le point même de T07.
//
// Un cours réel (pas les cours de démo bundlés dans CoursRepository, qui ne
// transitent jamais par Firestore et rendraient le test du cache trivial/
// sans objet) est semé directement dans l'émulateur avant de passer
// hors-ligne, pour que le test porte bien sur le cache Firestore et non sur
// un contenu toujours disponible par construction.
//
// Coupure réseau : `$.native.enableAirplaneMode()`/`disableAirplaneMode()`
// (patrol, automation native Android). Le retour en ligne est confirmé par
// `FirebaseFirestore.instance.waitForPendingWrites()` — pas seulement un
// délai arbitraire — avant de vérifier que l'écriture de progression
// effectuée hors-ligne a bien atteint le serveur.
//
// Non exécutable dans ce Codespace (aucun émulateur/adb, voir README.md §7).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:greenaccess/main.dart' as app;
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';

import 'helpers/e2e_helpers.dart';

const _courseId = 'e2e-t07-course';
const _courseTitre = 'E2E T07 — Cours hors-ligne';

void main() {
  patrolTest(
    'T07 — cours en cache, quiz complété hors-ligne, puis synchronisé au retour du réseau',
    ($) async {
      await app.main();
      await $.pumpAndSettle();

      final email = uniqueEmail('e2e-t07');
      const password = 'GreenAccessE2E1!';

      // Arrange : compte + un cours réel avec un quiz à une question.
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;
      await AuthRepository().saveUserProfile(UserModel(
        id: uid,
        nom: 'E2E T07',
        email: email,
        telephone: '',
        pays: 'Sénégal',
        region: 'Dakar',
        secteur: 'Agriculture',
        dateInscription: DateTime.now(),
        profilComplet: true,
        role: UserRole.user,
      ));
      await FirebaseFirestore.instance.collection('courses').doc(_courseId).set({
        'titre': _courseTitre,
        'theme': 'Test E2E',
        'description': 'Cours semé pour le scénario T07 (hors-ligne).',
        'objectifs': <String>[],
        'type': 'infographie', // pas de lien externe requis pour ce type
        'duree_min': 5,
        'points_xp': 10,
        'niveau_requis': 0,
        'nb_quiz': 1,
        'actif': true,
        'quiz': [
          {
            'id': 'q1',
            'question': 'Combien font 2 + 2 ?',
            'options': ['3', '4', '5'],
            'correct_index': 1,
            'type': 'qcm',
          },
        ],
      });
      await FirebaseAuth.instance.signOut();

      await skipOnboardingToLogin($);
      await $(TextFormField).at(0).enterText(email);
      await $(TextFormField).at(1).enterText(password);
      await $('Se connecter').tap();
      await $.pumpAndSettle();
      expect($('Accès rapide'), findsOneWidget);

      // Consultation en ligne : télécharge le cours dans le cache Firestore local.
      await $('Formation').at(0).tap();
      await $.pumpAndSettle();
      await $(_courseTitre).tap();
      await $.pumpAndSettle();
      expect($(_courseTitre), findsWidgets);
      await $.native.pressBack();
      await $.pumpAndSettle();

      // Passage hors-ligne.
      await $.native.enableAirplaneMode();

      // Le cours reste consultable : servi depuis le cache local, sans réseau.
      await $(_courseTitre).tap();
      await $.pumpAndSettle();
      expect($(_courseTitre), findsWidgets);

      // Quiz complété hors-ligne : l'écriture de progression est mise en
      // file d'attente localement par le SDK Firestore (écriture optimiste),
      // pas encore synchronisée avec le serveur à ce stade.
      await $('Passer le quiz (+XP)').tap();
      await $.pumpAndSettle();
      expect($('Question 1 / 1'), findsOneWidget);
      await $('4').tap(); // options[1], correct_index: 1
      await $('Terminer').tap();
      await $.pumpAndSettle();
      expect($('Retour au cours'), findsOneWidget);

      // Retour en ligne : synchronisation réelle de l'écriture en attente.
      await $.native.disableAirplaneMode();
      await FirebaseFirestore.instance
          .waitForPendingWrites()
          .timeout(const Duration(seconds: 20));

      final progress = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc(_courseId)
          .get();
      expect(progress.exists, isTrue);
      expect(progress.data()?['statut'], 'TERMINE');
      expect(progress.data()?['score_quiz'], 100);
    },
  );
}
