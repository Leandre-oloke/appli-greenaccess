// Généré à partir de google-services.json — projet GreenAccess Firebase
// Project ID: greenaccess-16d25

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      if (web.appId.startsWith('REMPLACER')) {
        throw UnsupportedError(
          'Config Web Firebase manquante. Dans la console Firebase : '
          'Paramètres du projet → Vos applications → Ajouter une app Web, '
          'puis reportez apiKey et appId dans `web` ci-dessous (lib/firebase_options.dart).',
        );
      }
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions n\'est pas configuré pour iOS. '
          'Ajoutez votre app iOS dans la console Firebase et relancez flutterfire configure.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions n\'est pas disponible pour cette plateforme : $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDYx9XiqjJxVSndd5XzXp18u1T85B_srrU',
    appId: '1:590719492442:android:7cf4b981965ba918209363',
    messagingSenderId: '590719492442',
    projectId: 'greenaccess-16d25',
    storageBucket: 'greenaccess-16d25.firebasestorage.app',
  );

  // Config Web — nécessaire pour exécuter l'app dans un navigateur (Codespaces).
  // Enregistrez une app Web dans la console Firebase (Paramètres du projet →
  // Vos applications → Web) et reportez ici `apiKey` et `appId`.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDYx9XiqjJxVSndd5XzXp18u1T85B_srrU',
    appId: '1:590719492442:web:0b0252fe16fa42c8209363',
    messagingSenderId: '590719492442',
    projectId: 'greenaccess-16d25',
    authDomain: 'greenaccess-16d25.firebaseapp.com',
    storageBucket: 'greenaccess-16d25.firebasestorage.app',
  );
}
