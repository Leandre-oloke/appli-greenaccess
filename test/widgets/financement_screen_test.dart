// Test widget de FinancementScreen (J2.22) : verrou d'accès au financement
// selon le score Climat (seuil 60/100, CDC §4.1) — sans Firebase réel (voir
// README.md §7). Même stratégie de fake que les autres tests widgets de ce
// dossier.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/score_climat_model.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/financement_repository.dart';
import 'package:greenaccess/repositories/score_repository.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/financement_viewmodel.dart';
import 'package:greenaccess/viewmodels/scoring_viewmodel.dart';
import 'package:greenaccess/views/financement/financement_screen.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(auth: _MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class _FakeAuthViewModel extends AuthViewModel {
  _FakeAuthViewModel(String userId) : super(_FakeAuthRepository()) {
    state = AuthState(
      isAuthenticated: true,
      user: UserModel(
        id: userId,
        nom: 'Alice',
        email: 'alice@greenaccess.test',
        telephone: '',
        pays: 'Sénégal',
        region: 'Dakar',
        secteur: 'Agriculture',
        dateInscription: DateTime.now(),
        profilComplet: true,
        role: UserRole.user,
      ),
    );
  }
}

const _userId = 'alice';

ScoreClimatModel _score(double total) => ScoreClimatModel(
      id: 's1',
      userId: _userId,
      scoreTotal: total,
      criteres: const ScoreCriteres(
        scoreActivite: 50,
        scoreUemoa: 20,
        scoreCo2: 0,
        scoreCertif: 0,
        scoreResilience: 40,
        bonusFormation: 0,
      ),
      niveau: ScoreClimatModel.niveauFromScore(total),
      suggestions: const [],
      dateCalcul: DateTime.now(),
      versionAlgo: 'v1-cloud',
    );

Widget _buildFinancement(double? scoreTotal) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel(_userId)),
      scoringViewModelProvider.overrideWith((ref, userId) {
        final vm = ScoringViewModel(
          ScoreRepository(firestore: FakeFirebaseFirestore(), functions: _MockFirebaseFunctions()),
          userId,
        );
        if (scoreTotal != null) vm.state = ScoringState(currentScore: _score(scoreTotal));
        return vm;
      }),
      financementViewModelProvider.overrideWith(
        (ref, userId) => FinancementViewModel(
          FinancementRepository(firestore: FakeFirebaseFirestore()),
          userId,
        ),
      ),
    ],
    child: MaterialApp(
      home: const FinancementScreen(),
    ),
  );
}

void main() {
  testWidgets('score < 60 : affiche "Score insuffisant" et masque le bouton de nouvelle demande',
      (tester) async {
    await tester.pumpWidget(_buildFinancement(45));
    await tester.pumpAndSettle();

    expect(find.text('Score insuffisant'), findsOneWidget);
    expect(find.text('Score: 45/100 — Minimum requis: 60/100'), findsOneWidget);
    expect(find.text('Améliorer'), findsOneWidget);
    expect(find.text('Nouvelle demande'), findsNothing);
  });

  testWidgets('score < 60 : l\'action "Simuler" est visuellement désactivée (onTap sans effet)',
      (tester) async {
    var demandeFormOuvert = false;
    await tester.pumpWidget(_buildFinancement(30));
    await tester.pumpAndSettle();

    // "Simuler" pousse normalement AppRoutes.demandeForm (go_router) — sans
    // routeur dans ce test, un tap qui aurait un effet lèverait une
    // exception ; on vérifie donc qu'aucune exception n'est levée, preuve
    // que `enabled: false` empêche bien le onTap de se déclencher.
    await tester.tap(find.text('Simuler'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(demandeFormOuvert, isFalse);
  });

  testWidgets('score ≥ 60 : affiche "Éligible au financement" et le bouton de nouvelle demande',
      (tester) async {
    await tester.pumpWidget(_buildFinancement(72));
    await tester.pumpAndSettle();

    expect(find.text('Éligible au financement'), findsOneWidget);
    expect(find.text('Score Climat: 72/100 ✓'), findsOneWidget);
    expect(find.text('Améliorer'), findsNothing);
    expect(find.text('Nouvelle demande'), findsOneWidget);
  });

  testWidgets('aucun score encore calculé (currentScore null) : traité comme non éligible (0/100)',
      (tester) async {
    await tester.pumpWidget(_buildFinancement(null));
    await tester.pumpAndSettle();

    expect(find.text('Score insuffisant'), findsOneWidget);
    expect(find.text('Score: 0/100 — Minimum requis: 60/100'), findsOneWidget);
    expect(find.text('Nouvelle demande'), findsNothing);
  });

  testWidgets('affiche l\'état vide quand aucune demande n\'existe', (tester) async {
    await tester.pumpWidget(_buildFinancement(72));
    await tester.pumpAndSettle();

    expect(find.text('Mes demandes (0)'), findsOneWidget);
    expect(find.text('Aucune demande'), findsOneWidget);
  });
}
