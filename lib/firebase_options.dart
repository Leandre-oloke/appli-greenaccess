// Généré à partir de google-services.json — projet GreenAccess Firebase
// Project ID: greenaccess-16d25

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions n\'est pas configuré pour le Web. '
        'Ajoutez votre app Web dans la console Firebase.',
      );
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
}
