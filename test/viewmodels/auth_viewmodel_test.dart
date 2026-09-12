// Tests unitaires de AuthViewModel (J2.23) — même style que
// assurance_viewmodel_test.dart : un fake AuthRepository qui n'appelle
// jamais Firebase réel, injecté via ProviderContainer.overrides. Couvre la
// connexion, l'inscription (dont la détection/nettoyage de compte orphelin
// — profil Firestore supprimé par un admin mais compte Auth jamais
// nettoyé), la déconnexion et la traduction des codes FirebaseAuthException
// en messages affichables.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

// `Fake` (pas `Mock`) : on implémente juste le getter réellement utilisé
// (credential.user!.uid dans AuthViewModel.register()) sans passer par
// when()/thenReturn — un Mock nu échoue sur un getter non-nullable (uid)
// stubé via when() sans génération de code (@GenerateMocks), faute de
// valeur "dummy" pour String.
class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);
  @override
  final String uid;
}

class _FakeUserCredential extends Fake implements UserCredential {
  _FakeUserCredential(this.user);
  @override
  final User? user;
}

UserCredential _credentialFor(String uid) => _FakeUserCredential(_FakeUser(uid));

// ── Fake AuthRepository ──────────────────────────────────────────────────────

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(auth: _MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  // AuthViewModel._init() (appelé par le constructeur) écoute
  // authStateChanges immédiatement — sans cet override, ça délègue à
  // _MockFirebaseAuth.authStateChanges() non stubbé (throw / null).
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  /// File d'utilisateurs renvoyés par getCurrentUser() successifs (un appel
  /// = un élément retiré) — permet de simuler des scénarios où l'état du
  /// "compte courant" change entre deux appels (ex. orphelin détecté).
  final List<UserModel?> currentUserQueue = [];
  UserCredential? credentialToReturn;
  Object? signInError;
  Object? registerError;
  bool orphanedAccountDeleted = false;
  UserModel? savedProfile;
  bool signOutCalled = false;
  Object? changePasswordError;
  Object? deleteAccountError;
  bool deleteAccountCalled = false;

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    if (signInError != null) throw signInError!;
    return credentialToReturn!;
  }

  @override
  Future<UserCredential> registerWithEmail(String email, String password) async {
    if (registerError != null) {
      final err = registerError!;
      registerError = null; // n'échoue qu'une fois (utile pour _cleanOrphanAndRetry)
      throw err;
    }
    return credentialToReturn!;
  }

  @override
  Future<UserModel?> getCurrentUser() async =>
      currentUserQueue.isNotEmpty ? currentUserQueue.removeAt(0) : null;

  @override
  Future<void> deleteOrphanedAuthAccount() async {
    orphanedAccountDeleted = true;
  }

  @override
  Future<void> saveUserProfile(UserModel user) async {
    savedProfile = user;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (changePasswordError != null) throw changePasswordError!;
  }

  @override
  Future<void> deleteAccount(String password) async {
    deleteAccountCalled = true;
    if (deleteAccountError != null) throw deleteAccountError!;
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

UserModel _user({String id = 'uid1', UserRole role = UserRole.user}) => UserModel(
      id: id,
      nom: 'Alice',
      email: 'alice@greenaccess.test',
      telephone: '',
      pays: 'Sénégal',
      region: 'Dakar',
      secteur: 'Agriculture',
      dateInscription: DateTime.now(),
      profilComplet: true,
      role: role,
    );

ProviderContainer _makeContainer(_FakeAuthRepository repo) {
  return ProviderContainer(
    overrides: [
      authViewModelProvider.overrideWith((ref) => AuthViewModel(repo)),
    ],
  );
}

void main() {
  group('AuthViewModel — signIn', () {
    test('succès : état authentifié avec le profil retourné par getCurrentUser', () async {
      final repo = _FakeAuthRepository()
        ..credentialToReturn = _credentialFor('uid1')
        ..currentUserQueue.add(_user());
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(authViewModelProvider.notifier).signIn('alice@x.com', 'pass123');
      final state = container.read(authViewModelProvider);

      expect(state.isAuthenticated, isTrue);
      expect(state.user?.id, 'uid1');
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('compte orphelin (Auth existe, profil Firestore absent) : supprime le compte et affiche un message',
        () async {
      final repo = _FakeAuthRepository()
        ..credentialToReturn = _credentialFor('uid1')
        ..currentUserQueue.add(null); // getCurrentUser() ne trouve aucun profil
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(authViewModelProvider.notifier).signIn('alice@x.com', 'pass123');
      final state = container.read(authViewModelProvider);

      expect(repo.orphanedAccountDeleted, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.error, contains('supprimé par un administrateur'));
    });

    test('mappe les codes FirebaseAuthException en messages affichables', () async {
      final cases = {
        'wrong-password': 'Mot de passe incorrect',
        'user-not-found': 'Aucun compte avec cet email',
        'email-already-in-use': 'Cet email est déjà utilisé',
        'weak-password': 'Mot de passe trop faible (6 caractères min)',
        'network-request-failed': 'Erreur réseau. Réessayez.',
        'too-many-requests': 'Trop de tentatives. Réessayez plus tard.',
        'code-totalement-inconnu': 'Une erreur est survenue. Réessayez.',
      };

      for (final entry in cases.entries) {
        final repo = _FakeAuthRepository()
          ..signInError = FirebaseAuthException(code: entry.key);
        final container = _makeContainer(repo);
        addTearDown(container.dispose);

        await container.read(authViewModelProvider.notifier).signIn('alice@x.com', 'pass123');
        final state = container.read(authViewModelProvider);

        expect(state.error, entry.value, reason: 'code ${entry.key}');
        expect(state.isAuthenticated, isFalse);
        expect(state.isLoading, isFalse);
      }
    });
  });

  group('AuthViewModel — register', () {
    test('succès : crée le profil avec role user et authentifie', () async {
      final repo = _FakeAuthRepository()..credentialToReturn = _credentialFor('uid-new');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(authViewModelProvider.notifier).register(
            'bob@x.com',
            'pass123',
            _user(),
          );
      final state = container.read(authViewModelProvider);

      expect(state.isAuthenticated, isTrue);
      expect(state.user?.id, 'uid-new');
      expect(state.user?.role, UserRole.user);
      expect(state.user?.profilComplet, isFalse);
      expect(repo.savedProfile?.id, 'uid-new');
    });

    test('email-already-in-use + compte réellement actif : reste en erreur, se déconnecte',
        () async {
      final repo = _FakeAuthRepository()
        ..registerError = FirebaseAuthException(code: 'email-already-in-use')
        ..credentialToReturn = _credentialFor('uid-existing')
        ..currentUserQueue.add(_user(id: 'uid-existing')); // compte NON orphelin
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(authViewModelProvider.notifier).register(
            'bob@x.com',
            'pass123',
            _user(),
          );
      final state = container.read(authViewModelProvider);

      expect(repo.signOutCalled, isTrue);
      expect(repo.orphanedAccountDeleted, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.error, 'Cet email est déjà utilisé');
    });

    test('email-already-in-use + compte orphelin : nettoie et recrée le profil', () async {
      final repo = _FakeAuthRepository()
        ..registerError = FirebaseAuthException(code: 'email-already-in-use')
        ..credentialToReturn = _credentialFor('uid-recreated')
        ..currentUserQueue.add(null); // getCurrentUser() après le 1er signIn : orphelin confirmé
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(authViewModelProvider.notifier).register(
            'bob@x.com',
            'pass123',
            _user(),
          );
      final state = container.read(authViewModelProvider);

      expect(repo.orphanedAccountDeleted, isTrue);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.id, 'uid-recreated');
      expect(repo.savedProfile?.id, 'uid-recreated');
    });
  });

  group('AuthViewModel — signOut / updateProfile', () {
    test('signOut() réinitialise l\'état par défaut', () async {
      final repo = _FakeAuthRepository()
        ..credentialToReturn = _credentialFor('uid1')
        ..currentUserQueue.add(_user());
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(authViewModelProvider.notifier).signIn('alice@x.com', 'pass');
      await container.read(authViewModelProvider.notifier).signOut();
      final state = container.read(authViewModelProvider);

      expect(repo.signOutCalled, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
    });

    test('updateProfile() sauvegarde et met à jour l\'utilisateur en état', () async {
      final repo = _FakeAuthRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final updated = _user().copyWith(nom: 'Alice Modifiée');
      await container.read(authViewModelProvider.notifier).updateProfile(updated);
      final state = container.read(authViewModelProvider);

      expect(repo.savedProfile?.nom, 'Alice Modifiée');
      expect(state.user?.nom, 'Alice Modifiée');
    });
  });

  group('AuthViewModel — changePassword', () {
    test('succès : retourne null', () async {
      final repo = _FakeAuthRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(authViewModelProvider.notifier)
          .changePassword('ancien', 'nouveau123');

      expect(result, isNull);
      expect(container.read(authViewModelProvider).isLoading, isFalse);
    });

    test('mappe les erreurs (mot de passe actuel incorrect)', () async {
      final repo = _FakeAuthRepository()
        ..changePasswordError = FirebaseAuthException(code: 'wrong-password');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(authViewModelProvider.notifier)
          .changePassword('mauvais', 'nouveau123');

      expect(result, 'Mot de passe actuel incorrect');
      expect(container.read(authViewModelProvider).error, 'Mot de passe actuel incorrect');
    });
  });

  group('AuthViewModel — deleteAccount', () {
    test('succès : réinitialise l\'état et retourne null', () async {
      final repo = _FakeAuthRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container.read(authViewModelProvider.notifier).deleteAccount('pass');

      expect(result, isNull);
      expect(repo.deleteAccountCalled, isTrue);
      expect(container.read(authViewModelProvider).isAuthenticated, isFalse);
    });

    test('mot de passe incorrect : conserve l\'état non authentifié avec message', () async {
      final repo = _FakeAuthRepository()
        ..deleteAccountError = FirebaseAuthException(code: 'wrong-password');
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container.read(authViewModelProvider.notifier).deleteAccount('mauvais');

      expect(result, 'Mot de passe incorrect');
      expect(container.read(authViewModelProvider).error, 'Mot de passe incorrect');
    });
  });
}
