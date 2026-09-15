// Test widget de CourseListScreen (Refonte frontend, Phase 3 — étape 4 :
// Formation) : recherche + filtre par thème (GaFilterBar), états
// vide/chargement/erreur. Aucun test n'existait auparavant sur cet écran.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/course_model.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/cours_repository.dart';
import 'package:greenaccess/ui/ui.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/formation_viewmodel.dart';
import 'package:greenaccess/views/formation/course_list_screen.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(auth: _MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class _FakeAuthViewModel extends AuthViewModel {
  _FakeAuthViewModel() : super(_FakeAuthRepository()) {
    state = AuthState(
      isAuthenticated: true,
      user: UserModel(
        id: _userId,
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

/// N'appelle jamais réellement loadCourses() : DashboardScreen/CourseListScreen
/// déclenchent l'appel réel au montage (postFrameCallback), qui écraserait
/// sinon tout état injecté à la main (même piège documenté dans
/// dashboard_screen_test.dart).
class _FakeFormationViewModel extends FormationViewModel {
  _FakeFormationViewModel(super.repository, super.userId);

  @override
  Future<void> loadCourses() async {}
}

CourseModel _course(String id, String titre, String theme) => CourseModel(
      id: id,
      titre: titre,
      theme: theme,
      type: CourseType.video,
      dureeMin: 10,
      pointsXp: 20,
      niveauRequis: 0,
      nbQuiz: 2,
      actif: true,
    );

Widget _buildScreen(FormationState state) {
  final vm = _FakeFormationViewModel(CoursRepository(firestore: FakeFirebaseFirestore()), _userId)
    ..state = state;
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel()),
      formationViewModelProvider.overrideWith((ref, userId) => vm),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const CourseListScreen()),
  );
}

void main() {
  testWidgets('affiche tous les cours par défaut', (tester) async {
    await tester.pumpWidget(_buildScreen(FormationState(courses: [
      _course('c1', 'Compostage', 'Agriculture'),
      _course('c2', 'Panneaux solaires', 'Énergie'),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('Compostage'), findsOneWidget);
    expect(find.text('Panneaux solaires'), findsOneWidget);
  });

  testWidgets('la recherche filtre par titre', (tester) async {
    await tester.pumpWidget(_buildScreen(FormationState(courses: [
      _course('c1', 'Compostage', 'Agriculture'),
      _course('c2', 'Panneaux solaires', 'Énergie'),
    ])));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'compost');
    await tester.pumpAndSettle();

    expect(find.text('Compostage'), findsOneWidget);
    expect(find.text('Panneaux solaires'), findsNothing);
  });

  testWidgets('le filtre par thème restreint la liste', (tester) async {
    await tester.pumpWidget(_buildScreen(FormationState(courses: [
      _course('c1', 'Compostage', 'Agriculture'),
      _course('c2', 'Panneaux solaires', 'Énergie'),
    ])));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Énergie'));
    await tester.pumpAndSettle();

    expect(find.text('Panneaux solaires'), findsOneWidget);
    expect(find.text('Compostage'), findsNothing);
  });

  testWidgets('aucun résultat affiche un état vide dédié', (tester) async {
    await tester.pumpWidget(_buildScreen(FormationState(courses: [
      _course('c1', 'Compostage', 'Agriculture'),
    ])));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pumpAndSettle();

    expect(find.text('Aucun cours trouvé'), findsOneWidget);
  });

  // Pas de test dédié à l'état isLoading (GaSkeletonList) : GaSkeleton anime
  // indéfiniment (shimmer en boucle via flutter_animate), et ce ticker ne se
  // désenregistre pas de façon fiable avant la vérification "aucun timer en
  // attente" du test binding en fin de test — même limitation déjà
  // documentée pour le squelette du Dashboard (README §8, étape 3).

  testWidgets('état d\'erreur affiche un GaErrorView traduit', (tester) async {
    await tester.pumpWidget(_buildScreen(const FormationState(error: 'boom')));
    await tester.pumpAndSettle();

    expect(find.byType(GaErrorView), findsOneWidget);
    expect(find.text('Une erreur est survenue. Réessayez.'), findsOneWidget);
  });

  testWidgets('le bouton badges porte un tooltip', (tester) async {
    await tester.pumpWidget(_buildScreen(const FormationState()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mes badges'), findsOneWidget);
  });
}
