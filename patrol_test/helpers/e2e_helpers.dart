// Aides partagées par les scénarios E2E Patrol (J6.1-J6.3, CDC §7.1-§7.2).
//
// Tourne sur un émulateur Android réel piloté par Patrol, contre le Firebase
// Emulator Suite lancé sur la machine hôte du runner CI — l'app y accède via
// `10.0.2.2` (alias standard de l'hôte depuis un émulateur Android), voir
// `--dart-define=EMULATOR_HOST=10.0.2.2` dans .github/workflows/e2e.yml et
// `lib/main.dart` pour le câblage. Non exécutable dans ce Codespace : aucun
// `adb`/émulateur Android disponible ici (voir README.md §7) — seul un GitHub
// Actions runner (`ubuntu-latest`, virtualisation KVM) ou un poste local avec
// Android Studio peut réellement piloter ces tests.
import 'dart:convert';
import 'dart:io';

import 'package:patrol/patrol.dart';

const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
const _firebaseProjectId = 'greenaccess-16d25';

/// Passe l'écran d'onboarding (bouton « Passer ») pour atteindre l'écran de
/// connexion — chaque run E2E démarre avec des SharedPreferences vierges
/// (app fraîchement installée sur l'émulateur), donc `onboarding_shown` est
/// toujours à revoir.
Future<void> skipOnboardingToLogin(PatrolIntegrationTester $) async {
  await $('Passer').waitUntilVisible();
  await $('Passer').tap();
  await $.pumpAndSettle();
}

/// Interroge l'API REST de test de l'émulateur Auth
/// (`emulator/v1/projects/{id}/verificationCodes`, voir le code source de
/// `firebase-tools` — src/emulator/auth/operations.ts — non documentée
/// publiquement mais stable) pour récupérer le code OTP réellement généré
/// pour un numéro de téléphone donné, sans jamais l'envoyer par SMS (l'Auth
/// Emulator ne délivre aucun SMS réel). Poll avec un petit délai : le code
/// n'est écrit qu'après la réponse de `verifyPhoneNumber()` côté app.
Future<String> fetchOtpCode(String phoneNumber) async {
  final client = HttpClient();
  try {
    for (var attempt = 0; attempt < 20; attempt++) {
      final uri = Uri.parse(
        'http://$emulatorHost:9099/emulator/v1/projects/$_firebaseProjectId/verificationCodes',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final codes = (data['verificationCodes'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .where((c) => c['phoneNumber'] == phoneNumber)
          .toList();
      if (codes.isNotEmpty) {
        // Le plus récent en dernier — utile si un test renvoie le code
        // (bouton "Renvoyer le code").
        return codes.last['code'] as String;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    throw StateError('Aucun code OTP émulé reçu pour $phoneNumber après 6 s.');
  } finally {
    client.close();
  }
}

/// Numéro de téléphone unique par exécution — évite toute collision avec un
/// run précédent sur un émulateur Auth dont l'état persiste le temps du job
/// CI (même besoin que `_uniqueEmail` dans integration_test/auth_repository_test.dart).
String uniquePhoneNumber() {
  final suffix = (DateTime.now().millisecondsSinceEpoch % 1000000000).toString().padLeft(9, '7');
  return '+221$suffix';
}

String uniqueEmail(String tag) => '$tag-${DateTime.now().millisecondsSinceEpoch}@greenaccess.test';
