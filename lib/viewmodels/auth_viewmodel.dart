import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthViewModel extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthViewModel(this._repository) : super(const AuthState()) {
    _init();
  }

  void _init() {
    _repository.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        // Evite le double fetch : signIn/register set déjà l'état directement.
        if (state.isAuthenticated && state.user?.id == firebaseUser.uid) return;
        final user = await _repository.getCurrentUser();
        if (user != null) {
          state = state.copyWith(user: user, isAuthenticated: true, isLoading: false);
        }
      } else {
        state = const AuthState();
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.signInWithEmail(email, password);
      final user = await _repository.getCurrentUser();

      if (user == null) {
        // Compte Firebase Auth existant mais profil Firestore supprimé par un admin.
        // Suppression du compte Auth orphelin pour permettre une future re-inscription.
        await _repository.deleteOrphanedAuthAccount();
        // Laisser _init() traiter authStateChanges(null) avant d'écrire l'erreur.
        await Future.delayed(const Duration(milliseconds: 100));
        state = state.copyWith(
          isLoading: false,
          error: 'Ce compte a été supprimé par un administrateur. '
              'Vous pouvez vous réinscrire avec cet email.',
        );
        return;
      }

      state = state.copyWith(user: user, isLoading: false, isAuthenticated: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapError(e));
    }
  }

  Future<void> register(String email, String password, UserModel profile) async {
    state = state.copyWith(isLoading: true);
    try {
      final credential = await _repository.registerWithEmail(email, password);
      final newUser = _buildNewUser(credential.user!.uid, email, profile);
      await _repository.saveUserProfile(newUser);
      state = state.copyWith(user: newUser, isLoading: false, isAuthenticated: true);
    } catch (e) {
      // Si l'email est déjà utilisé, vérifier si c'est un compte Auth orphelin
      // (doc Firestore supprimé par un admin mais compte Auth jamais nettoyé).
      if (e.toString().contains('email-already-in-use')) {
        final cleaned = await _cleanOrphanAndRetry(email, password, profile);
        if (cleaned) return;
      }
      state = state.copyWith(isLoading: false, error: _mapError(e));
    }
  }

  UserModel _buildNewUser(String uid, String email, UserModel profile) {
    return UserModel(
      id: uid,
      nom: profile.nom,
      email: email,
      telephone: profile.telephone,
      pays: profile.pays,
      region: profile.region,
      secteur: profile.secteur,
      dateInscription: DateTime.now(),
      profilComplet: false,
      role: UserRole.user,
    );
  }

  /// Tente de se connecter avec les identifiants fournis pour détecter un compte
  /// Auth orphelin (Auth existe, Firestore doc absent). Si orphelin : supprime le
  /// compte Auth puis recrée un profil complet. Retourne true si réussi.
  Future<bool> _cleanOrphanAndRetry(String email, String password, UserModel profile) async {
    try {
      await _repository.signInWithEmail(email, password);
      final existingUser = await _repository.getCurrentUser();

      if (existingUser != null) {
        // Vrai compte actif (pas orphelin) → on se déconnecte et on laisse
        // l'erreur "email déjà utilisé" remonter normalement.
        await _repository.signOut();
        return false;
      }

      // Compte orphelin confirmé : Auth OK mais aucun doc Firestore.
      await _repository.deleteOrphanedAuthAccount();
      await Future.delayed(const Duration(milliseconds: 150));

      // Recréer le compte avec les mêmes identifiants.
      final credential = await _repository.registerWithEmail(email, password);
      final newUser = _buildNewUser(credential.user!.uid, email, profile);
      await _repository.saveUserProfile(newUser);
      state = state.copyWith(user: newUser, isLoading: false, isAuthenticated: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.sendOtpSms(phoneNumber);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapError(e));
    }
  }

  Future<void> verifyOtp(String smsCode) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.verifyOtpCode(smsCode);
      final user = await _repository.getCurrentUser();
      state = state.copyWith(user: user, isLoading: false, isAuthenticated: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapError(e));
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState();
  }

  Future<void> updateProfile(UserModel updatedUser) async {
    await _repository.saveUserProfile(updatedUser);
    state = state.copyWith(user: updatedUser);
  }

  /// Retourne null en cas de succès, ou le message d'erreur.
  Future<String?> deleteAccount(String password) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteAccount(password);
      state = const AuthState();
      return null;
    } catch (e) {
      final msg = _mapDeleteError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

  /// Retourne null en cas de succès, ou le message d'erreur.
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.changePassword(currentPassword, newPassword);
      state = state.copyWith(isLoading: false);
      return null;
    } catch (e) {
      final msg = _mapChangePasswordError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

  String _mapChangePasswordError(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Mot de passe actuel incorrect',
        'weak-password'        => 'Nouveau mot de passe trop faible (6 caractères min)',
        'requires-recent-login'=> 'Reconnectez-vous puis réessayez',
        'network-request-failed' => 'Erreur réseau. Réessayez.',
        _ => 'Impossible de modifier le mot de passe. Réessayez.',
      };
    }
    return 'Impossible de modifier le mot de passe. Réessayez.';
  }

  String _mapDeleteError(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Mot de passe incorrect',
        'requires-recent-login' => 'Reconnectez-vous puis réessayez',
        'network-request-failed' => 'Erreur réseau. Réessayez.',
        _ => 'Suppression impossible. Réessayez.',
      };
    }
    return 'Suppression impossible. Réessayez.';
  }

  String _mapError(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Mot de passe incorrect',
        'user-not-found'       => 'Aucun compte avec cet email',
        'email-already-in-use' => 'Cet email est déjà utilisé',
        'weak-password'        => 'Mot de passe trop faible (6 caractères min)',
        'network-request-failed' => 'Erreur réseau. Réessayez.',
        'too-many-requests'    => 'Trop de tentatives. Réessayez plus tard.',
        _ => 'Une erreur est survenue. Réessayez.',
      };
    }
    return 'Une erreur est survenue. Réessayez.';
  }
}

final authViewModelProvider = StateNotifierProvider<AuthViewModel, AuthState>(
  (ref) => AuthViewModel(AuthRepository()),
);
