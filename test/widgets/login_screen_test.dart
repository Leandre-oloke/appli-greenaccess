// Test widget de LoginScreen (J2.17) : validation de formulaire et affichage
// des états d'erreur/chargement — sans Firebase réel (voir README.md §7 sur
// pourquoi un flutter test classique ne peut pas parler à un émulateur).
//
// authViewModelProvider construit un vrai AuthRepository() par défaut, dont
// le constructeur évalue FirebaseAuth.instance/FirebaseFirestore.instance
// (throw sans Firebase.initializeApp()). On l'override donc par un
// _FakeAuthViewModel qui étend AuthViewModel (requis par le typage du
// provider) mais dont le AuthRepository sous-jacent ne touche jamais
// FirebaseAuth : firestore fourni par fake_cloud_firestore, authStateChanges
// (seul appel fait par AuthViewModel à la construction) surchargé pour ne
// jamais toucher _auth, et Mock (mockito) implémentant FirebaseAuth juste
// pour satisfaire le typage du constructeur — jamais réellement invoqué.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/ui/ui.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/views/auth/login_screen.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(auth: _MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class _FakeAuthViewModel extends AuthViewModel {
  _FakeAuthViewModel({AuthState? initialState, this.onSignIn}) : super(_FakeAuthRepository()) {
    if (initialState != null) state = initialState;
  }

  final void Function(String email, String password)? onSignIn;

  @override
  Future<void> signIn(String email, String password) async {
    onSignIn?.call(email, password);
  }
}

Widget _buildLogin(AuthViewModel Function(Ref ref) createViewModel) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith(createViewModel),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const LoginScreen(),
    ),
  );
}

void main() {
  testWidgets('affiche les champs email/mot de passe et le bouton de connexion', (tester) async {
    await tester.pumpWidget(_buildLogin((ref) => _FakeAuthViewModel()));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
  });

  testWidgets("affiche les erreurs de validation quand le formulaire est vide", (tester) async {
    var signInCalled = false;
    await tester.pumpWidget(_buildLogin(
      (ref) => _FakeAuthViewModel(onSignIn: (_, __) => signInCalled = true),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Email invalide'), findsOneWidget);
    expect(find.text('Minimum 6 caractères'), findsOneWidget);
    expect(signInCalled, isFalse);
  });

  testWidgets("affiche l'erreur email pour une adresse sans @, même avec un mot de passe valide", (tester) async {
    var signInCalled = false;
    await tester.pumpWidget(_buildLogin(
      (ref) => _FakeAuthViewModel(onSignIn: (_, __) => signInCalled = true),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email').first, 'pas-un-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'motdepasse123');
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Email invalide'), findsOneWidget);
    expect(signInCalled, isFalse);
  });

  testWidgets('appelle signIn quand le formulaire est valide', (tester) async {
    String? capturedEmail;
    String? capturedPassword;
    await tester.pumpWidget(_buildLogin(
      (ref) => _FakeAuthViewModel(
        onSignIn: (email, password) {
          capturedEmail = email;
          capturedPassword = password;
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'alice@greenaccess.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'motdepasse123');
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Email invalide'), findsNothing);
    expect(find.text('Minimum 6 caractères'), findsNothing);
    expect(capturedEmail, 'alice@greenaccess.test');
    expect(capturedPassword, 'motdepasse123');
  });

  testWidgets("affiche le bandeau d'erreur quand authState.error est renseigné", (tester) async {
    await tester.pumpWidget(_buildLogin(
      (ref) => _FakeAuthViewModel(
        initialState: const AuthState(error: 'Mot de passe incorrect'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mot de passe incorrect'), findsOneWidget);
  });

  testWidgets("affiche un indicateur de chargement et désactive le bouton quand authState.isLoading est vrai", (tester) async {
    var signInCalled = false;
    await tester.pumpWidget(_buildLogin(
      (ref) => _FakeAuthViewModel(
        initialState: const AuthState(isLoading: true),
        onSignIn: (_, __) => signInCalled = true,
      ),
    ));
    // pas de pumpAndSettle() ici : le CircularProgressIndicator du bouton en
    // chargement anime indéfiniment (spinner indéterminé), pumpAndSettle()
    // attendrait la fin d'une animation qui ne se termine jamais. pump(Duration.zero)
    // (et non pump() nu) pour laisser flutter_animate exécuter les timers à
    // durée nulle qu'il programme pour (re)démarrer la cascade d'entrée
    // (gaStagger) — sinon le framework de test les signale comme "encore en
    // attente" à la fin du test.
    await tester.pump(Duration.zero);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Se connecter'), findsNothing);

    // Le bouton est désactivé pendant le chargement (onPressed: null).
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump(Duration.zero);
    expect(signInCalled, isFalse);
  });
}
