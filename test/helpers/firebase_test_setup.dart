import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Initialise Firebase avec des canaux factices pour les tests unitaires.
/// À appeler dans `setUpAll` des tests qui instancient des repos Firebase.
Future<void> setupFirebaseForTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fakeOptions = <String, dynamic>{
    'apiKey': 'fake-api-key',
    'appId': '1:000000:android:000000',
    'messagingSenderId': '000000',
    'projectId': 'fake-project',
  };

  // Mock du canal firebase_core (méthode utilisée par firebase_core >=3.x)
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_core'),
    (MethodCall call) async {
      switch (call.method) {
        case 'Firebase#initializeCore':
          return [
            {
              'name': '[DEFAULT]',
              'options': fakeOptions,
              'pluginConstants': <String, dynamic>{},
            }
          ];
        case 'Firebase#initializeApp':
          return {
            'name': call.arguments['appName'] ?? '[DEFAULT]',
            'options': fakeOptions,
            'pluginConstants': <String, dynamic>{},
          };
        default:
          return null;
      }
    },
  );

  // Mock du canal cloud_functions (évite tout appel natif)
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/cloud_functions'),
    (_) async => null,
  );

  await Firebase.initializeApp();
}
