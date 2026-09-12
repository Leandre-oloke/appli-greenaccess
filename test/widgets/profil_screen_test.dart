// Test widget de ProfilScreen (J3.6) : rend la portabilité des données
// accessible depuis l'écran Profil — bouton « Télécharger mes données »,
// ouverture du choix de format (PDF/CSV), sans Firebase réel (voir
// README.md §7). Même stratégie de fake que les autres tests widgets.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/export_repository.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/export_viewmodel.dart';
import 'package:greenaccess/views/profil/profil_screen.dart';

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
        id: 'alice',
        nom: 'Alice Dupont',
        email: 'alice@greenaccess.test',
        telephone: '+221700000000',
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

class _FakeExportViewModel extends ExportViewModel {
  _FakeExportViewModel() : super(ExportRepository(firestore: FakeFirebaseFirestore()));

  String? lastCallUserId;
  String? lastFormat;

  @override
  Future<void> exportAsPdf(String userId) async {
    lastCallUserId = userId;
    lastFormat = 'pdf';
  }

  @override
  Future<void> exportAsCsv(String userId) async {
    lastCallUserId = userId;
    lastFormat = 'csv';
  }
}

/// Le bouton est en bas d'un long formulaire défilant (SingleChildScrollView) :
/// hors du viewport par défaut du test, un tap() dessus rate silencieusement
/// (l'offset calculé tombe hors de la zone visible). `ensureVisible()` fait
/// défiler jusqu'au bouton avant de taper dessus.
Future<void> _tapExportButton(WidgetTester tester) async {
  final finder = find.widgetWithText(OutlinedButton, 'Télécharger mes données');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Widget _buildProfil(_FakeExportViewModel exportViewModel) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel()),
      exportViewModelProvider.overrideWith((ref) => exportViewModel),
    ],
    child: const MaterialApp(home: ProfilScreen()),
  );
}

void main() {
  testWidgets('affiche le bouton « Télécharger mes données »', (tester) async {
    await tester.pumpWidget(_buildProfil(_FakeExportViewModel()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Télécharger mes données'), findsOneWidget);
  });

  testWidgets('ouvre un choix de format PDF/CSV au tap sur le bouton', (tester) async {
    await tester.pumpWidget(_buildProfil(_FakeExportViewModel()));
    await tester.pumpAndSettle();

    await _tapExportButton(tester);
    await tester.pumpAndSettle();

    expect(find.text('Exporter mes données'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'CSV'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'PDF'), findsOneWidget);
  });

  testWidgets('choisir « CSV » appelle exportAsCsv() avec l\'id de l\'utilisateur courant',
      (tester) async {
    final exportViewModel = _FakeExportViewModel();
    await tester.pumpWidget(_buildProfil(exportViewModel));
    await tester.pumpAndSettle();

    await _tapExportButton(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'CSV'));
    await tester.pumpAndSettle();

    expect(exportViewModel.lastFormat, 'csv');
    expect(exportViewModel.lastCallUserId, 'alice');
    // La boîte de dialogue se ferme après l'export.
    expect(find.text('Exporter mes données'), findsNothing);
  });

  testWidgets('choisir « PDF » appelle exportAsPdf() avec l\'id de l\'utilisateur courant',
      (tester) async {
    final exportViewModel = _FakeExportViewModel();
    await tester.pumpWidget(_buildProfil(exportViewModel));
    await tester.pumpAndSettle();

    await _tapExportButton(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'PDF'));
    await tester.pumpAndSettle();

    expect(exportViewModel.lastFormat, 'pdf');
    expect(exportViewModel.lastCallUserId, 'alice');
  });
}
