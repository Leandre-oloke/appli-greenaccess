// Test widget de NotificationsScreen (Refonte frontend, Phase 3 — étape 8 :
// Notifications) : recherche + filtre par type (GaFilterBar), GaListTile.
// Aucun test n'existait auparavant sur cet écran.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/notification_repository.dart';
import 'package:greenaccess/ui/ui.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/notification_viewmodel.dart';
import 'package:greenaccess/views/notifications/notifications_screen.dart';

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

Future<Widget> _buildScreen({List<Map<String, dynamic>> notifs = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = FakeFirebaseFirestore();
  for (final n in notifs) {
    await db.collection('notifications').add(n);
  }

  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel()),
      notificationViewModelProvider.overrideWith(
        (ref, userId) => NotificationViewModel(NotificationRepository(db: db), prefs, userId),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const NotificationsScreen()),
  );
}

Map<String, dynamic> _notif(String titre, String message, String type, {DateTime? at}) => {
      'titre': titre,
      'message': message,
      'type': type,
      'createdAt': Timestamp.fromDate(at ?? DateTime.now()),
    };

/// Comme dans dashboard_screen_test.dart : au viewport par défaut du test
/// (~600px de haut), le contenu combiné (barre de filtre + tuiles) peut
/// dépasser la hauteur visible. On élargit le viewport plutôt que de
/// scroller.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('affiche toutes les notifications par défaut', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(await _buildScreen(notifs: [
      _notif('Maintenance prévue', 'Le service sera indisponible demain.', 'info'),
      _notif('Demande approuvée', 'Votre dossier a été validé.', 'success'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Maintenance prévue'), findsOneWidget);
    expect(find.text('Demande approuvée'), findsOneWidget);
  });

  testWidgets('la recherche filtre par titre', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(await _buildScreen(notifs: [
      _notif('Maintenance prévue', 'Le service sera indisponible demain.', 'info'),
      _notif('Demande approuvée', 'Votre dossier a été validé.', 'success'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'approuvée');
    await tester.pumpAndSettle();

    expect(find.text('Demande approuvée'), findsOneWidget);
    expect(find.text('Maintenance prévue'), findsNothing);
  });

  testWidgets('le filtre par type restreint la liste', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(await _buildScreen(notifs: [
      _notif('Maintenance prévue', 'Le service sera indisponible demain.', 'info'),
      _notif('Demande approuvée', 'Votre dossier a été validé.', 'success'),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Succès'));
    await tester.pumpAndSettle();

    expect(find.text('Demande approuvée'), findsOneWidget);
    expect(find.text('Maintenance prévue'), findsNothing);
  });

  testWidgets('aucune notification affiche un état vide', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(await _buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Aucune notification'), findsOneWidget);
  });

  testWidgets('aucun résultat de recherche affiche un état vide dédié', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(await _buildScreen(notifs: [
      _notif('Maintenance prévue', 'Le service sera indisponible demain.', 'info'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pumpAndSettle();

    expect(find.text('Aucun résultat'), findsOneWidget);
  });
}
