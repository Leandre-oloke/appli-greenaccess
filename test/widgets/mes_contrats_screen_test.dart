// Test widget de MesContratsScreen (Refonte frontend, Phase 3 — étape 7 :
// Assurance) : erreur traduite dans le SnackBar (mapErrorToMessage), tooltip
// du bouton d'actualisation. Aucun test n'existait auparavant sur cet écran.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/assurance_repository.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/viewmodels/assurance_viewmodel.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/views/assurance/mes_contrats_screen.dart';

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

/// N'appelle jamais réellement loadContrats() au montage (postFrameCallback) :
/// évite d'écraser l'état injecté à la main, même piège documenté dans
/// dashboard_screen_test.dart.
class _FakeAssuranceViewModel extends AssuranceViewModel {
  _FakeAssuranceViewModel(super.repository, super.userId);

  @override
  Future<void> loadContrats() async {}
}

Widget _buildScreen(_FakeAssuranceViewModel vm) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel()),
      assuranceViewModelProvider.overrideWith((ref, userId) => vm),
    ],
    child: MaterialApp(home: const MesContratsScreen()),
  );
}

void main() {
  testWidgets('le bouton d\'actualisation porte un tooltip', (tester) async {
    final vm = _FakeAssuranceViewModel(AssuranceRepository(firestore: FakeFirebaseFirestore()), _userId);
    await tester.pumpWidget(_buildScreen(vm));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Actualiser'), findsOneWidget);
  });

  testWidgets('une erreur ViewModel affiche un message traduit, pas le texte technique brut',
      (tester) async {
    final vm = _FakeAssuranceViewModel(AssuranceRepository(firestore: FakeFirebaseFirestore()), _userId);
    await tester.pumpWidget(_buildScreen(vm));
    await tester.pumpAndSettle();

    const raw = 'FirebaseException: [cloud_firestore/unavailable] The service is unavailable.';
    vm.state = vm.state.copyWith(error: raw);
    await tester.pump();
    await tester.pump();

    expect(find.text(raw), findsNothing);
    expect(find.text('Une erreur est survenue. Réessayez.'), findsOneWidget);
  });
}
