import 'package:firebase_auth/firebase_auth.dart';

/// Traduit une exception technique en message utilisateur lisible en français.
///
/// Point d'entrée unique pour l'affichage d'erreur dans les ViewModels et les
/// écrans (`GaErrorView` / `GaInfoBanner`). Remplace les `e.toString()` bruts
/// affichés tels quels et les mappings ad-hoc dupliqués d'écran en écran
/// (`AuthViewModel._mapError`, `AdminViewModel._msg`, etc.).
String mapErrorToMessage(
  Object error, {
  String fallback = 'Une erreur est survenue. Réessayez.',
}) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'wrong-password' || 'invalid-credential' => 'Mot de passe incorrect',
      'user-not-found' => 'Aucun compte avec cet email',
      'email-already-in-use' => 'Cet email est déjà utilisé',
      'weak-password' => 'Mot de passe trop faible (6 caractères min)',
      'too-many-requests' => 'Trop de tentatives. Réessayez plus tard.',
      'requires-recent-login' => 'Reconnectez-vous puis réessayez',
      'account-exists-with-different-credential' =>
        'Un compte existe déjà avec cet email via une autre méthode de connexion.',
      'invalid-verification-code' => 'Code de vérification incorrect',
      'network-request-failed' => 'Erreur réseau. Vérifiez votre connexion.',
      _ => fallback,
    };
  }

  // `FirebaseAuthException` hérite de `FirebaseException` : ce bloc ne
  // s'applique donc qu'aux exceptions Firestore/Storage/Functions restantes.
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => "Permission refusée (vérifiez vos droits d'accès)",
      'unavailable' || 'network-request-failed' =>
        'Erreur réseau. Vérifiez votre connexion.',
      'not-found' => 'Élément introuvable',
      'deadline-exceeded' => 'Le serveur met trop de temps à répondre. Réessayez.',
      'already-exists' => 'Cet élément existe déjà',
      _ => fallback,
    };
  }

  return fallback;
}
