import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/prefs_provider.dart';
import 'theme.dart';
import 'routes.dart';
import 'firebase_options.dart';

// Handler background FCM — doit être une fonction top-level
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM background handler enregistré avant le lancement de l'app
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // Demande permission notifications (Android 13+ / iOS)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Cache Firestore offline
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

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
    _initFcmForegroundHandler();
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
