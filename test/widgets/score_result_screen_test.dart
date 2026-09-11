// Test widget de ScoreResultScreen (J2.19) : jauge, niveau, détail des
// critères et suggestions — sans Firebase réel (voir README.md §7). Même
// stratégie de fake que login_screen_test.dart/scoring_form_screen_test.dart.
//
// Boutons non testés ici (hors périmètre "jauge, niveau, suggestions") car
// ils appellent des APIs indisponibles en test VM sans routeur/plateforme
// réels : retour (context.canPop()/go_router), export PDF (Printing.sharePdf,
// canal plateforme), navigation financement/formation (go_router).
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
import 'package:greenaccess/repositories/score_repository.dart';
import 'package:greenaccess/ui/ui.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/scoring_viewmodel.dart';
import 'package:greenaccess/views/scoring/score_result_screen.dart';

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

class _FakeScoreRepository extends ScoreRepository {
  _FakeScoreRepository() : super(firestore: FakeFirebaseFirestore(), functions: _MockFirebaseFunctions());
}

class _FakeScoringViewModel extends ScoringViewModel {
  _FakeScoringViewModel(String userId, {required ScoringState initialState})
      : super(_FakeScoreRepository(), userId) {
    state = initialState;
  }
}

const _userId = 'alice';

ScoreClimatModel _score({
  required double total,
  required NiveauScore niveau,
  List<String> suggestions = const [],
}) {
  return ScoreClimatModel(
    id: 's1',
    userId: _userId,
    scoreTotal: total,
    criteres: const ScoreCriteres(
      scoreActivite: 90,
      scoreUemoa: 100,
      scoreCo2: 60,
      scoreCertif: 55,
      scoreResilience: 80,
      bonusFormation: 5,
    ),
    niveau: niveau,
    suggestions: suggestions,
    dateCalcul: DateTime.now(),
    versionAlgo: 'v1-cloud',
  );
}

Widget _buildScoreResult(ScoreClimatModel? score) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel(_userId)),
      scoringViewModelProvider.overrideWith(
        (ref, userId) => _FakeScoringViewModel(userId, initialState: ScoringState(currentScore: score)),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const ScoreResultScreen(),
    ),
  );
}

void main() {
  testWidgets("affiche un état vide quand aucun score n'est disponible", (tester) async {
    await tester.pumpWidget(_buildScoreResult(null));
    await tester.pumpAndSettle();

    expect(find.text('Aucun score disponible'), findsOneWidget);
  });

  testWidgets('affiche la jauge avec le score et le niveau "Bon" (60-79)', (tester) async {
    await tester.pumpWidget(_buildScoreResult(_score(total: 76, niveau: NiveauScore.bon)));
    await tester.pumpAndSettle();

    expect(find.text('76'), findsOneWidget);
    expect(find.text('/ 100'), findsOneWidget);
    expect(find.text('Bon'), findsOneWidget);
  });

  testWidgets('affiche le niveau "Excellent" pour un score ≥ 80', (tester) async {
    await tester.pumpWidget(_buildScoreResult(_score(total: 91, niveau: NiveauScore.excellent)));
    await tester.pumpAndSettle();

    expect(find.text('91'), findsOneWidget);
    expect(find.text('Excellent'), findsOneWidget);
  });

  testWidgets('affiche le détail des 5 critères et le bonus formation', (tester) async {
    await tester.pumpWidget(_buildScoreResult(_score(total: 79, niveau: NiveauScore.bon)));
    await tester.pumpAndSettle();

    expect(find.text('Activité verte'), findsOneWidget);
    expect(find.text('90/100'), findsOneWidget);
    expect(find.text('Alignement UEMOA'), findsOneWidget);
    expect(find.text('100/100'), findsOneWidget);
    expect(find.text('Réduction CO₂'), findsOneWidget);
    expect(find.text('60/100'), findsOneWidget);
    expect(find.text('Certifications'), findsOneWidget);
    expect(find.text('55/100'), findsOneWidget);
    expect(find.text('Résilience climatique'), findsOneWidget);
    expect(find.text('80/100'), findsOneWidget);
    expect(find.text('Bonus formations'), findsOneWidget);
    expect(find.text('+5 pts'), findsOneWidget);
  });

  testWidgets('affiche les suggestions quand présentes, et rien sinon', (tester) async {
    await tester.pumpWidget(_buildScoreResult(_score(
      total: 45,
      niveau: NiveauScore.intermediaire,
      suggestions: const ['Documentez votre réduction CO₂.', 'Obtenez une certification.'],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Comment progresser'), findsOneWidget);
    expect(find.text('Documentez votre réduction CO₂.'), findsOneWidget);
    expect(find.text('Obtenez une certification.'), findsOneWidget);
  });

  testWidgets("n'affiche pas la section suggestions quand la liste est vide", (tester) async {
    await tester.pumpWidget(_buildScoreResult(_score(total: 85, niveau: NiveauScore.excellent)));
    await tester.pumpAndSettle();

    expect(find.text('Comment progresser'), findsNothing);
  });

  testWidgets('score ≥ 60 : bandeau succès et bouton « Demander un financement »', (tester) async {
    await tester.pumpWidget(_buildScoreResult(_score(total: 65, niveau: NiveauScore.bon)));
    await tester.pumpAndSettle();

    expect(
      find.text('Score ≥ 60 : vous pouvez soumettre une demande de financement vert.'),
      findsOneWidget,
    );
    expect(find.text('Demander un financement'), findsOneWidget);
    expect(find.text('Améliorer via formation'), findsNothing);
  });

  testWidgets('score < 60 : bandeau avertissement et bouton « Améliorer via formation »',
      (tester) async {
    await tester.pumpWidget(_buildScoreResult(_score(total: 45, niveau: NiveauScore.intermediaire)));
    await tester.pumpAndSettle();

    expect(
      find.text('Score < 60 : complétez des formations pour améliorer votre score.'),
      findsOneWidget,
    );
    expect(find.text('Améliorer via formation'), findsOneWidget);
    expect(find.text('Demander un financement'), findsNothing);
  });
}
