// Test widget de DemandeFormScreen (J2.20) : navigation du stepper 7 étapes
// et validation par étape — sans Firebase réel (voir README.md §7). Même
// stratégie de fake que les autres tests widgets de ce dossier.
//
// En l'écrivant, un bug réel est apparu : _onNext() ne validait jamais le
// Form avant d'avancer (aucun appel à _formKey.currentState.validate()),
// donc les validators "Requis"/"Minimum 20 caractères" des étapes 1-2
// n'étaient jamais déclenchés — "Suivant" avançait toujours. Corrigé dans
// demande_form_screen.dart.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/financement_repository.dart';
import 'package:greenaccess/repositories/score_repository.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/financement_viewmodel.dart';
import 'package:greenaccess/viewmodels/scoring_viewmodel.dart';
import 'package:greenaccess/views/financement/demande_form_screen.dart';

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
        nom: 'Alice Dupont',
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

Widget _buildDemandeForm() {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel(_userId)),
      // Backés par de vrais fakes Firestore (fake_cloud_firestore) plutôt que
      // par des sous-classes : ScoringViewModel/FinancementViewModel n'ont
      // aucun effet de bord dans leur constructeur, et leurs repositories
      // par défaut évalueraient FirebaseFirestore.instance/FirebaseFunctions
      // .instanceFor(...) (throw sans Firebase.initializeApp()).
      scoringViewModelProvider.overrideWith(
        (ref, userId) => ScoringViewModel(
          ScoreRepository(firestore: FakeFirebaseFirestore(), functions: _MockFirebaseFunctions()),
          userId,
        ),
      ),
      financementViewModelProvider.overrideWith(
        (ref, userId) => FinancementViewModel(
          FinancementRepository(firestore: FakeFirebaseFirestore()),
          userId,
        ),
      ),
    ],
    child: MaterialApp(
      home: const DemandeFormScreen(),
    ),
  );
}

void main() {
  testWidgets("affiche l'étape 1/7 pré-remplie avec le profil de l'utilisateur", (tester) async {
    await tester.pumpWidget(_buildDemandeForm());
    await tester.pumpAndSettle();

    expect(find.text('Étape 1 / 7'), findsOneWidget);
    expect(find.text('Identité & Profil'), findsOneWidget);
    expect(find.text('Alice Dupont'), findsOneWidget); // nom pré-rempli depuis authViewModelProvider
  });

  testWidgets('bloque le passage à l\'étape 2 si le nom est vidé (validation "Requis")',
      (tester) async {
    await tester.pumpWidget(_buildDemandeForm());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom complet'), '');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Suivant'));
    await tester.pumpAndSettle();

    expect(find.text('Requis'), findsOneWidget);
    expect(find.text('Étape 1 / 7'), findsOneWidget); // toujours sur l'étape 1
  });

  testWidgets("avance à l'étape 2 une fois le nom renseigné", (tester) async {
    await tester.pumpWidget(_buildDemandeForm());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Suivant'));
    await tester.pumpAndSettle();

    expect(find.text('Étape 2 / 7'), findsOneWidget);
    // "Description du projet" est à la fois le titre de l'étape et le label
    // du champ texte — les deux sont attendus.
    expect(find.text('Description du projet'), findsNWidgets(2));
  });

  testWidgets('bloque le passage à l\'étape 3 si la description fait moins de 20 caractères',
      (tester) async {
    await tester.pumpWidget(_buildDemandeForm());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Suivant')); // → étape 2
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description du projet'),
      'Trop court',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Suivant'));
    await tester.pumpAndSettle();

    expect(find.text('Minimum 20 caractères'), findsOneWidget);
    expect(find.text('Étape 2 / 7'), findsOneWidget);
  });

  testWidgets("avance jusqu'à l'étape 7 une fois toutes les étapes obligatoires valides",
      (tester) async {
    await tester.pumpWidget(_buildDemandeForm());
    await tester.pumpAndSettle();

    // Étape 1 : nom déjà pré-rempli.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Étape 2 / 7'), findsOneWidget);

    // Étape 2 : nom du projet requis + description ≥ 20 caractères.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom du projet'),
      'Maraîchage solaire',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description du projet'),
      'Extension d\'une exploitation maraîchère biologique avec irrigation solaire.',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Étape 3 / 7'), findsOneWidget);

    // Étapes 3-6 : aucun champ requis, "Suivant" avance directement.
    for (final titre in ['Étape 4 / 7', 'Étape 5 / 7', 'Étape 6 / 7', 'Étape 7 / 7']) {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Suivant'));
      await tester.pumpAndSettle();
      expect(find.text(titre), findsOneWidget);
    }

    expect(find.text('Revue et soumission'), findsOneWidget);
    expect(find.text('Soumettre la demande'), findsOneWidget);
  });

  testWidgets(
    'à la dernière étape, « Soumettre la demande » reste désactivé tant que la case '
    'de confirmation n\'est pas cochée',
    (tester) async {
      await tester.pumpWidget(_buildDemandeForm());
      await tester.pumpAndSettle();

      // Étape 1
      await tester.tap(find.widgetWithText(ElevatedButton, 'Suivant'));
      await tester.pumpAndSettle();
      // Étape 2
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom du projet'),
        'Maraîchage solaire',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description du projet'),
        'Extension d\'une exploitation maraîchère biologique avec irrigation solaire.',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Suivant'));
      await tester.pumpAndSettle();
      // Étapes 3-6
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Suivant'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Étape 7 / 7'), findsOneWidget);
      var button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Soumettre la demande'));
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Soumettre la demande'));
      expect(button.onPressed, isNotNull);
    },
  );
}
