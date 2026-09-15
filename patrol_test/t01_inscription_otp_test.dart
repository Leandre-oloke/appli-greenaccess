// E2E T01 (J6.2, CDC §7.2 · T01) : inscription par numéro de téléphone (OTP)
// jusqu'au tableau de bord, en moins de 3 s à partir de la saisie du dernier
// chiffre du code.
//
// En écrivant ce scénario, deux bugs réels de production sont apparus et ont
// été corrigés (voir README.md §8 pour le détail) :
//  1. Aucun bouton de l'app ne menait jamais à OTPScreen malgré sa route
//     publique déjà déclarée dans routes.dart — un écran mort. Corrigé en
//     ajoutant un bouton « Continuer avec un numéro de téléphone » sur
//     LoginScreen.
//  2. AuthViewModel.verifyOtp() ne créait jamais de profil Firestore pour un
//     nouvel utilisateur OTP : `isAuthenticated` passait à `true` mais
//     `user` restait `null` pour toujours, et DashboardScreen
//     (`if (user == null) return const SizedBox.shrink();`) restait
//     indéfiniment vide. Corrigé en créant un profil minimal à la première
//     connexion (même pattern que _createProfileFromGoogle).
//
// Non exécutable dans ce Codespace (aucun émulateur/adb, voir README.md §7)
// — validé en CI (.github/workflows/e2e.yml) contre un Android émulé réel et
// le Firebase Emulator Suite (jamais de vrai SMS envoyé : le code OTP est
// récupéré via l'API REST de test de l'Auth Emulator, voir
// helpers/e2e_helpers.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:greenaccess/main.dart' as app;

import 'helpers/e2e_helpers.dart';

void main() {
  patrolTest(
    'T01 — inscription par OTP jusqu\'au tableau de bord en moins de 3 s',
    ($) async {
      await app.main();
      await $.pumpAndSettle();
      await skipOnboardingToLogin($);

      await $('Continuer avec un numéro de téléphone').tap();
      await $.pumpAndSettle();

      // Pays par défaut (+221 Sénégal) conservé — seul le numéro est saisi,
      // sans l'indicatif ni le 0 initial (voir le texte d'aide d'OTPScreen).
      final phone = uniquePhoneNumber();
      final localNumber = phone.substring(4); // retire "+221"
      await $(TextFormField).enterText(localNumber);
      await $('Envoyer le code SMS').tap();
      await $.pumpAndSettle();

      expect($('Entrez le code reçu'), findsOneWidget);

      final code = await fetchOtpCode(phone);
      expect(code, hasLength(6));

      // Le 6e chiffre déclenche la vérification automatique
      // (OTPScreen._onDigitChanged) — pas besoin de taper explicitement sur
      // « Vérifier le code ». Le chronomètre démarre juste avant, s'arrête
      // dès que le tableau de bord est visible.
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 6; i++) {
        await $(TextField).at(i).enterText(code[i]);
      }
      await $.pumpAndSettle();
      stopwatch.stop();

      // Marqueur stable du tableau de bord — pas le nom de l'utilisateur : un
      // inscrit par OTP démarre avec un profil minimal (`nom: ''`, complété
      // plus tard), donc la salutation seule n'est pas un repère fiable ici.
      expect($('Accès rapide'), findsOneWidget);
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 3)),
        reason:
            'T01 exige un passage OTP → tableau de bord en moins de 3 s (CDC §7.2).',
      );
    },
  );
}
