// Test widget de ScoringFormScreen (J2.18) : navigation des 5 étapes du
// stepper, aller-retour, soumission finale — sans Firebase réel (voir
// README.md §7). Même stratégie de fake que login_screen_test.dart :
// _FakeScoringViewModel/_FakeAuthViewModel étendent les vraies classes
// (requis par le typage des providers family/simple) mais leurs repositories
// sous-jacents ne touchent jamais Firebase.
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
import 'package:greenaccess/views/scoring/scoring_form_screen.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(auth: _MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

/// AuthViewModel dont l'utilisateur est déjà connecté (userId fixe), pour
/// que scoringViewModelProvider(userId) soit stable pendant tout le test.
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
  _FakeScoringViewModel(
    String userId, {
    ScoringState? initialState,
    this.onSubmit,
  }) : super(_FakeScoreRepository(), userId) {
    if (initialState != null) state = initialState;
  }

  final Future<ScoreClimatModel?> Function(Map<String, dynamic> data)? onSubmit;

  @override
  Future<ScoreClimatModel?> soumettreCriteres(Map<String, dynamic> data) async {
    if (onSubmit == null) return null;
    state = state.copyWith(isCalculating: true);
    final score = await onSubmit!(data);
    state = state.copyWith(isCalculating: false, currentScore: score);
    return score;
  }
}

const _userId = 'alice';

Widget _buildScoringForm({
  ScoringState? initialState,
  Future<ScoreClimatModel?> Function(Map<String, dynamic> data)? onSubmit,
}) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel(_userId)),
      scoringViewModelProvider.overrideWith(
        (ref, userId) => _FakeScoringViewModel(userId, initialState: initialState, onSubmit: onSubmit),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const ScoringFormScreen(),
    ),
  );
}

void main() {
  testWidgets("affiche l'étape 1/5 avec les choix d'activité", (tester) async {
    await tester.pumpWidget(_buildScoringForm());
    await tester.pumpAndSettle();

    expect(find.text('Étape 1 / 5'), findsOneWidget);
    expect(find.text('Quelle est votre activité ?'), findsOneWidget);
    expect(find.text('Énergie renouvelable'), findsOneWidget);
    expect(find.text('Retour'), findsNothing); // pas de bouton retour sur la 1re étape
  });

  testWidgets('« Suivant » avance à travers les 5 étapes puis affiche « Calculer mon score »',
      (tester) async {
    await tester.pumpWidget(_buildScoringForm());
    await tester.pumpAndSettle();

    const titres = [
      'Quelle est votre activité ?',
      'Alignement à la taxonomie UEMOA',
      'Impact CO₂ estimé',
      'Vos certifications',
      'Votre résilience climatique',
    ];

    for (var i = 0; i < titres.length; i++) {
      expect(find.text('Étape ${i + 1} / 5'), findsOneWidget);
      expect(find.text(titres[i]), findsOneWidget);

      final isLast = i == titres.length - 1;
      await tester.tap(find.text(isLast ? 'Calculer mon score' : 'Suivant'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('« Retour » revient à l\'étape précédente sans perdre la sélection', (tester) async {
    await tester.pumpWidget(_buildScoringForm());
    await tester.pumpAndSettle();

    // Étape 1 : change l'activité sélectionnée, puis avance.
    await tester.tap(find.text('Recyclage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Étape 2 / 5'), findsOneWidget);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('Étape 1 / 5'), findsOneWidget);
    // La carte "Recyclage" reste sélectionnée (état conservé par le State du
    // formulaire, pas recréé à chaque étape).
    expect(find.text('Recyclage'), findsOneWidget);
  });

  testWidgets('soumet les critères par défaut avec les bonnes clés à la dernière étape',
      (tester) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(_buildScoringForm(
      onSubmit: (data) async {
        submitted = data;
        return null;
      },
    ));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Calculer mon score'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!['type_activite'], 'Agriculture');
    expect(submitted!['alignement_uemoa'], 'Non');
    expect(submitted!['co2_evite'], 0.0);
    expect(submitted!['certifications'], isEmpty);
    expect(submitted!['resilience'], 3);
  });

  testWidgets('sélectionner des certifications les inclut dans la soumission', (tester) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(_buildScoringForm(
      onSubmit: (data) async {
        submitted = data;
        return null;
      },
    ));
    await tester.pumpAndSettle();

    // Étapes 1-3 : avancer sans rien changer.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Vos certifications'), findsOneWidget);

    await tester.tap(find.text('Bio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ISO 14001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculer mon score'));
    await tester.pumpAndSettle();

    expect(submitted!['certifications'], containsAll(['Bio', 'ISO 14001']));
    expect((submitted!['certifications'] as List).length, 2);
  });

  testWidgets("affiche le bandeau d'erreur avec l'action « Voir les cours »", (tester) async {
    await tester.pumpWidget(_buildScoringForm(
      initialState: const ScoringState(
        error: 'Le calcul du score est momentanément indisponible. Réessayez dans '
            'quelques instants, ou complétez des formations en attendant.',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Calcul du score indisponible'), findsOneWidget);
    expect(find.text('Voir les cours'), findsOneWidget);
  });
}
