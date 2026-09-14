// Test widget de BadgesScreen (J5.16) : bouton d'export des badges
// (JSON/PDF), sans Firebase réel (voir README.md §7). Même stratégie de
// fake que les autres tests widgets de ce dossier.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/cours_repository.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/formation_viewmodel.dart';
import 'package:greenaccess/views/formation/badges_screen.dart';

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

/// Les vraies méthodes appelleraient `share_plus`/`printing`, indisponibles
/// en test (canaux de plateforme réels) — même stratégie que
/// `_FakeExportViewModel` dans profil_screen_test.dart.
class _FakeFormationViewModel extends FormationViewModel {
  _FakeFormationViewModel(super.repository, super.userId);

  String? lastFormat;

  @override
  Future<void> exporterBadgesJson() async {
    lastFormat = 'json';
  }

  @override
  Future<void> exporterBadgesPdf() async {
    lastFormat = 'pdf';
  }
}

Widget _buildBadges(_FakeFormationViewModel vm) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel()),
      formationViewModelProvider.overrideWith((ref, userId) => vm),
    ],
    child: const MaterialApp(home: BadgesScreen()),
  );
}

void main() {
  testWidgets("le bouton d'export est désactivé quand aucun badge n'est obtenu", (tester) async {
    final db = FakeFirebaseFirestore();
    final vm = _FakeFormationViewModel(CoursRepository(firestore: db), _userId);

    await tester.pumpWidget(_buildBadges(vm));
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.ios_share));
    expect(button.onPressed, isNull);
  });

  testWidgets("le bouton d'export ouvre le choix JSON/PDF quand au moins un badge est obtenu",
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(_userId).collection('badges').doc('assure_climat').set({
      'nom': 'Assuré Climat',
      'description': 'Vous avez souscrit à votre première assurance climatique.',
      'image_url': '',
      'type': 'assurance',
      'date_obtention': DateTime.now(),
    });
    final vm = _FakeFormationViewModel(CoursRepository(firestore: db), _userId);

    await tester.pumpWidget(_buildBadges(vm));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.ios_share));
    await tester.pumpAndSettle();

    expect(find.text('Exporter mes badges'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
  });

  testWidgets('choisir « JSON » appelle exporterBadgesJson()', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(_userId).collection('badges').doc('assure_climat').set({
      'nom': 'Assuré Climat', 'description': '', 'image_url': '', 'type': 'assurance',
      'date_obtention': DateTime.now(),
    });
    final vm = _FakeFormationViewModel(CoursRepository(firestore: db), _userId);

    await tester.pumpWidget(_buildBadges(vm));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.ios_share));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();

    expect(vm.lastFormat, 'json');
  });

  testWidgets('choisir « PDF » appelle exporterBadgesPdf()', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(_userId).collection('badges').doc('assure_climat').set({
      'nom': 'Assuré Climat', 'description': '', 'image_url': '', 'type': 'assurance',
      'date_obtention': DateTime.now(),
    });
    final vm = _FakeFormationViewModel(CoursRepository(firestore: db), _userId);

    await tester.pumpWidget(_buildBadges(vm));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.ios_share));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();

    expect(vm.lastFormat, 'pdf');
  });
}
