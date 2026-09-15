import 'package:firebase_core/firebase_core.dart';

import 'core/env/app_env.dart';
import 'firebase_options.dart';

/// Options Firebase à utiliser selon l'environnement ([AppEnvironment]).
///
/// Un seul projet Firebase existe à ce jour (`greenaccess-16d25`) : les deux
/// branches pointent dessus, donc `--dart-define=APP_ENV=dev` ne change rien
/// au backend pour l'instant — le mécanisme de bascule est en place, prêt à
/// brancher un vrai projet de dev dès qu'il existe.
///
/// Pour créer et brancher un projet de dev :
/// 1. Console Firebase → nouveau projet (ex. `greenaccess-16d25-dev`)
/// 2. `flutterfire configure --project=greenaccess-16d25-dev --out=lib/firebase_options_dev.dart`
/// 3. `import 'firebase_options_dev.dart' as dev_options;` ci-dessous, et
///    remplacer le `case AppEnv.dev` par `dev_options.DefaultFirebaseOptions.currentPlatform`
FirebaseOptions currentFirebaseOptions() {
  switch (AppEnvironment.current) {
    case AppEnv.dev:
    case AppEnv.prod:
      return DefaultFirebaseOptions.currentPlatform;
  }
}
