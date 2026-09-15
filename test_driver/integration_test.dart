// Point d'entrée requis par `flutter drive` pour les tests d'intégration web
// (integration_test/). Voir README.md §7 pour l'état actuel (bloqué) et le
// contexte : commande normalement utilisée une fois débloqué —
//   chromedriver --port=4444 &
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/auth_repository_test.dart \
//     -d web-server --web-port=7357 --browser-name=chrome
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
