// Test de fumée Patrol (J6.1, CDC §7.1) : prouve que le harnais E2E est
// opérationnel — l'app démarre réellement (Firebase + émulateurs + routeur)
// sur un appareil/émulateur, indépendamment de la logique de n'importe quel
// scénario métier (T01/T04, voir les autres fichiers de ce dossier).
//
// Non exécutable dans ce Codespace (aucun émulateur/adb, voir README.md §7)
// — validé en CI (.github/workflows/e2e.yml, Android hardware-accelerated
// sur ubuntu-latest) et exécutable en local sur un poste avec un émulateur
// Android ou un appareil connecté : `patrol test -t patrol_test/app_test.dart`.
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:greenaccess/main.dart' as app;

void main() {
  patrolTest('Patrol est opérationnel : l\'app démarre et affiche l\'écran de connexion',
      ($) async {
    await app.main();
    await $.pumpAndSettle();

    // Splash (1,5 s puis redirection) → onboarding (SharedPreferences vierges
    // sur une app fraîchement installée) → « Passer » → connexion.
    await $('Passer').waitUntilVisible();
    await $('Passer').tap();
    await $.pumpAndSettle();

    expect($('Se connecter'), findsWidgets);
  });
}
