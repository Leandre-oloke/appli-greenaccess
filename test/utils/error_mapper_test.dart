// Tests unitaires de mapErrorToMessage (Phase « Refonte frontend », Design
// System — mapping d'erreur centralisé remplaçant les e.toString() bruts).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/utils/error_mapper.dart';

void main() {
  group('mapErrorToMessage — FirebaseAuthException', () {
    test('wrong-password → message de mot de passe incorrect', () {
      expect(
        mapErrorToMessage(FirebaseAuthException(code: 'wrong-password')),
        'Mot de passe incorrect',
      );
    });

    test('user-not-found → message de compte introuvable', () {
      expect(
        mapErrorToMessage(FirebaseAuthException(code: 'user-not-found')),
        'Aucun compte avec cet email',
      );
    });

    test('code inconnu → message de repli générique', () {
      expect(
        mapErrorToMessage(FirebaseAuthException(code: 'code-jamais-vu')),
        'Une erreur est survenue. Réessayez.',
      );
    });

    test('fallback personnalisé respecté sur code inconnu', () {
      expect(
        mapErrorToMessage(
          FirebaseAuthException(code: 'code-jamais-vu'),
          fallback: 'Échec de connexion.',
        ),
        'Échec de connexion.',
      );
    });
  });

  group('mapErrorToMessage — FirebaseException (Firestore/Storage)', () {
    test('permission-denied → message de droits d\'accès', () {
      expect(
        mapErrorToMessage(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')),
        "Permission refusée (vérifiez vos droits d'accès)",
      );
    });

    test('unavailable → message d\'erreur réseau', () {
      expect(
        mapErrorToMessage(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')),
        'Erreur réseau. Vérifiez votre connexion.',
      );
    });

    test('not-found → message d\'élément introuvable', () {
      expect(
        mapErrorToMessage(FirebaseException(plugin: 'cloud_firestore', code: 'not-found')),
        'Élément introuvable',
      );
    });
  });

  group('mapErrorToMessage — exception non-Firebase', () {
    test('Exception générique → message de repli', () {
      expect(mapErrorToMessage(Exception('boom')), 'Une erreur est survenue. Réessayez.');
    });

    test('String brute → message de repli', () {
      expect(mapErrorToMessage('erreur inattendue'), 'Une erreur est survenue. Réessayez.');
    });
  });
}
