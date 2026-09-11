// Test d'intégration ScoreRepository contre les émulateurs Firebase (Auth +
// Firestore + Functions), via le package `integration_test` officiel.
// Actuellement bloqué en exécution — voir auth_repository_test.dart (même
// dossier) pour le diagnostic complet, et README.md §7.
//
// Ce fichier a été écrit en préparant la couverture de ScoreRepository et a
// immédiatement révélé 5 bugs réels de correspondance de clés entre le
// client Dart et la Cloud Function `calculerScoreClimat`
// (functions/src/index.ts) — corrigés dans le même commit : clés d'entrée
// snake_case→camelCase, libellés de certification manquants côté serveur,
// "criteres" absent de la réponse callable, clés du document Firestore
// persisté, région Cloud Functions par défaut incorrecte.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:greenaccess/firebase_options.dart';
import 'package:greenaccess/models/score_climat_model.dart';
import 'package:greenaccess/repositories/score_repository.dart';

const _emulatorHost = 'localhost';

String _uniqueEmail(String tag) =>
    '$tag-${DateTime.now().microsecondsSinceEpoch}@greenaccess.test';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ScoreRepository repo;

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8085);
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .useFunctionsEmulator(_emulatorHost, 5001);
    repo = ScoreRepository(
      firestore: FirebaseFirestore.instance,
      functions: FirebaseFunctions.instanceFor(region: 'europe-west1'),
    );
  });

  setUp(() async {
    await FirebaseAuth.instance.signOut();
  });

  test(
    'calculate() appelle la vraie Cloud Function et renvoie un score et des '
    'critères cohérents avec la formule CDC (pas les valeurs par défaut)',
    () async {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _uniqueEmail('score'),
        password: 'MotDePasse123!',
      );
      final userId = credential.user!.uid;

      final score = await repo.calculate(userId, {
        'type_activite': 'Énergie renouvelable', // 90
        'alignement_uemoa': 'Oui', // 100
        'co2_evite': 250.0, // co2ToScore → 80
        'certifications': ['Bio', 'ISO 14001'], // 25 + 30 = 55
        'resilience': 4, // 80
      });

      // Score = 90×0.25 + 100×0.20 + 80×0.20 + 55×0.20 + 80×0.15 + 0 = 81.5
      expect(score.scoreTotal, closeTo(81.5, 0.01));
      expect(score.niveau, NiveauScore.excellent);
      expect(score.criteres.scoreActivite, 90);
      expect(score.criteres.scoreUemoa, 100);
      expect(score.criteres.scoreCo2, 80);
      expect(score.criteres.scoreCertif, 55);
      expect(score.criteres.scoreResilience, 80);
      expect(score.criteres.bonusFormation, 0);
      expect(score.id, isNotEmpty);
    },
  );

  test('calculate() sans utilisateur connecté échoue proprement', () async {
    await expectLater(
      repo.calculate('un-uid-quelconque', {
        'type_activite': 'Agriculture',
        'alignement_uemoa': 'Non',
        'co2_evite': 0.0,
        'certifications': <String>[],
        'resilience': 1,
      }),
      throwsA(isA<ScoreCalculationException>()),
    );
  });

  test('saveScore() puis getLatestScore() (aller-retour Firestore pur)', () async {
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _uniqueEmail('savescore'),
      password: 'MotDePasse123!',
    );
    final userId = credential.user!.uid;

    const criteres = ScoreCriteres(
      scoreActivite: 75,
      scoreUemoa: 60,
      scoreCo2: 40,
      scoreCertif: 25,
      scoreResilience: 60,
      bonusFormation: 2,
    );
    final score = ScoreClimatModel(
      id: '',
      userId: userId,
      scoreTotal: 55.2,
      criteres: criteres,
      niveau: NiveauScore.intermediaire,
      suggestions: const ['Documentez votre réduction CO₂.'],
      dateCalcul: DateTime.now(),
      versionAlgo: 'v1-local',
    );
    await repo.saveScore(userId, score);

    final latest = await repo.getLatestScore(userId);
    expect(latest, isNotNull);
    expect(latest!.scoreTotal, 55.2);
    expect(latest.niveau, NiveauScore.intermediaire);
    expect(latest.criteres.scoreActivite, 75);
    expect(latest.suggestions, contains('Documentez votre réduction CO₂.'));
  });

  test('getHistory() renvoie les scores triés du plus récent au plus ancien', () async {
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _uniqueEmail('history'),
      password: 'MotDePasse123!',
    );
    final userId = credential.user!.uid;

    const criteres = ScoreCriteres(
      scoreActivite: 50,
      scoreUemoa: 20,
      scoreCo2: 0,
      scoreCertif: 0,
      scoreResilience: 20,
      bonusFormation: 0,
    );
    for (final total in [30.0, 45.0, 60.0]) {
      await repo.saveScore(
        userId,
        ScoreClimatModel(
          id: '',
          userId: userId,
          scoreTotal: total,
          criteres: criteres,
          niveau: ScoreClimatModel.niveauFromScore(total),
          suggestions: const [],
          dateCalcul: DateTime.now(),
          versionAlgo: 'v1-local',
        ),
      );
    }

    final history = await repo.getHistory(userId);
    expect(history.length, 3);
    expect(history.first.scoreTotal, 60.0);
    expect(history.last.scoreTotal, 30.0);
  });
}
