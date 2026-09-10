import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/prefs_provider.dart';
import 'theme.dart';
import 'routes.dart';
import 'firebase_options.dart';

// Bascule émulateurs Firebase : flutter run --dart-define=USE_EMULATOR=true
const bool kUseEmulator = bool.fromEnvironment('USE_EMULATOR');
const String kEmulatorHost =
    String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

// Handler background FCM — doit être une fonction top-level
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Cache Firestore offline (désactivé avec les émulateurs pour éviter les
  // incohérences de cache ; sur le Web le cache IndexedDB est géré par le SDK)
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: !kUseEmulator,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Émulateurs Firebase locaux (dev / Codespaces)
  if (kUseEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(kEmulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(kEmulatorHost, 8085);
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .useFunctionsEmulator(kEmulatorHost, 5001);
    await FirebaseStorage.instance.useStorageEmulator(kEmulatorHost, 9199);
  }

  // FCM — non pris en charge proprement sur le Web (service worker + clé VAPID requis)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // Ré-authentification obligatoire à chaque ouverture (app financière)
  await FirebaseAuth.instance.signOut();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const GreenAccessApp(),
  ));
}

class GreenAccessApp extends ConsumerStatefulWidget {
  const GreenAccessApp({super.key});

  @override
  ConsumerState<GreenAccessApp> createState() => _GreenAccessAppState();
}

class _GreenAccessAppState extends ConsumerState<GreenAccessApp> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _initFcmForegroundHandler();
  }

  void _initFcmForegroundHandler() {
    // Affiche une bannière quand une notification arrive en premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = message.notification;
      if (notif == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notif.title ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              if (notif.body != null)
                Text(notif.body!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'GreenAccess',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
