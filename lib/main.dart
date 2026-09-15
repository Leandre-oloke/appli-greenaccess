import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/env/app_env.dart';
import 'core/providers/prefs_provider.dart';
import 'core/providers/theme_mode_provider.dart';
import 'theme.dart';
import 'routes.dart';
import 'firebase_env.dart';

// Bascule émulateurs Firebase : flutter run --dart-define=USE_EMULATOR=true
const bool kUseEmulator = bool.fromEnvironment('USE_EMULATOR');
const String kEmulatorHost =
    String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

// Force la persistance Firestore même avec les émulateurs (J6.5, CDC §7.2 ·
// T07) : par défaut elle est désactivée avec les émulateurs (voir plus bas)
// pour éviter un cache local périmé entre deux redémarrages d'émulateur en
// dev — un souci qui ne se pose pas dans un run E2E Patrol isolé (l'émulateur
// démarre une seule fois, l'app tourne une seule fois). Flag dédié plutôt que
// de changer le comportement par défaut : `flutter test
// -d android --dart-define=USE_EMULATOR=true --dart-define=FORCE_PERSISTENCE=true`
// (voir patrol_test/t07_hors_ligne_test.dart et .github/workflows/e2e.yml).
const bool kForcePersistence = bool.fromEnvironment('FORCE_PERSISTENCE');

// Handler background FCM — doit être une fonction top-level
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: currentFirebaseOptions());
}

// `Future<void>` (pas `void`) : un `void main() async` ne peut pas être
// `await`é depuis l'extérieur (sémantique fire-and-forget du langage Dart)
// — nécessaire pour que les tests E2E Patrol (patrol_test/, J6.1-J6.3)
// puissent attendre la fin réelle du bootstrap (Firebase, émulateurs,
// SharedPreferences) avant d'interagir avec l'app. Aucun changement de
// comportement en production : le moteur Flutter n'attend jamais `main()`
// non plus.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) Animate.restartOnHotReload = true;
  await initializeDateFormatting('fr', null);
  await Firebase.initializeApp(options: currentFirebaseOptions());

  // Cache Firestore offline (désactivé avec les émulateurs pour éviter les
  // incohérences de cache, sauf si FORCE_PERSISTENCE=true — voir T07 ci-dessus ;
  // sur le Web le cache IndexedDB est géré par le SDK)
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: !kUseEmulator || kForcePersistence,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Traces de performance des écrans/opérations clés (J6.6, CDC §7.1 · T10) —
  // voir lib/utils/perf_trace.dart pour l'instrumentation elle-même.
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

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
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: AppEnvironment.isDev ? 'GreenAccess (DEV)' : 'GreenAccess',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
