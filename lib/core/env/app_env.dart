/// Environnement applicatif, choisi à la compilation.
///
/// `flutter run --dart-define=APP_ENV=dev` (ou `prod`, valeur par défaut si
/// omis). Indépendant de la bascule émulateurs (`USE_EMULATOR`, voir
/// `main.dart`) : [AppEnvironment] choisit le **projet Firebase** ciblé
/// (via `firebase_env.dart`), `USE_EMULATOR` choisit si on passe par les
/// émulateurs locaux de ce projet.
enum AppEnv { dev, prod }

abstract final class AppEnvironment {
  static const String _raw = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'prod',
  );

  static const AppEnv current = _raw == 'dev' ? AppEnv.dev : AppEnv.prod;

  static bool get isDev => current == AppEnv.dev;
  static bool get isProd => current == AppEnv.prod;

  /// Étiquette compacte affichable en debug (titre de fenêtre, bannière…).
  static String get label => isDev ? 'DEV' : 'PROD';
}
