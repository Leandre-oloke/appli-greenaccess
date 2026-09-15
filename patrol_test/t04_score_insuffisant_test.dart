// E2E T04 (J6.3, CDC §7.2 · T04) : un Score Climat inférieur à 60 bloque
// l'accès au financement et redirige vers la formation.
//
// L'inscription (T01) et le calcul de score sont déjà couverts par leurs
// propres scénarios/tests (T01 ci-contre, calculerScoreClimat.test.ts côté
// Cloud Functions) — ce test se concentre sur SA propre préoccupation : la
// règle de blocage. Le compte de test et son Score Climat insuffisant sont
// donc semés directement via les vraies classes du repo
// (AuthRepository.saveUserProfile, ScoreRepository.saveScore) plutôt que
// rejoués à travers l'écran de scoring en 5 étapes — seule l'authentification
// (formulaire email/mot de passe) est pilotée depuis l'UI, pour rester
// représentatif d'un parcours réel.
//
// Non exécutable dans ce Codespace (aucun émulateur/adb, voir README.md §7)
// — validé en CI (.github/workflows/e2e.yml) contre un Android émulé réel et
// le Firebase Emulator Suite.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:greenaccess/main.dart' as app;
import 'package:greenaccess/models/score_climat_model.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/score_repository.dart';

import 'helpers/e2e_helpers.dart';

void main() {
  patrolTest(
    'T04 — score < 60 : accès au financement bloqué, redirection vers la formation',
    ($) async {
      await app.main();
      await $.pumpAndSettle();

      final email = uniqueEmail('e2e-t04');
      const password = 'GreenAccessE2E1!';

      // Arrange : compte + profil complet + Score Climat insuffisant (45/100,
      // sous le seuil de 60 défini par ScoreClimatModel.peutDemanderFinancement).
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;
      await AuthRepository().saveUserProfile(UserModel(
        id: uid,
        nom: 'E2E T04',
        email: email,
        telephone: '',
        pays: 'Sénégal',
        region: 'Dakar',
        secteur: 'Agriculture',
        dateInscription: DateTime.now(),
        profilComplet: true,
        role: UserRole.user,
      ));
      await ScoreRepository().saveScore(
        uid,
        ScoreClimatModel(
          id: '',
          userId: uid,
          scoreTotal: 45,
          criteres: const ScoreCriteres(
            scoreActivite: 50,
            scoreUemoa: 20,
            scoreCo2: 0,
            scoreCertif: 0,
            scoreResilience: 40,
            bonusFormation: 0,
          ),
          niveau: NiveauScore.insuffisant,
          suggestions: const ['Complétez davantage de formations pour gagner des points bonus.'],
          dateCalcul: DateTime.now(),
          versionAlgo: 'v1-e2e-seed',
        ),
      );
      // L'inscription ci-dessus a signé l'utilisateur de test — l'app doit
      // démarrer déconnectée, comme après un vrai lancement (main() force
      // déjà signOut() avant runApp(), mais la création de compte vient de
      // resigner).
      await FirebaseAuth.instance.signOut();

      await skipOnboardingToLogin($);

      // Act : connexion via le vrai formulaire email/mot de passe.
      await $(TextFormField).at(0).enterText(email);
      await $(TextFormField).at(1).enterText(password);
      await $('Se connecter').tap();
      await $.pumpAndSettle();

      expect($('Accès rapide'), findsOneWidget, reason: 'connexion réussie, tableau de bord affiché');

      // 'Financement' apparaît deux fois sur le tableau de bord (tuile
      // d'accès rapide + carte détaillée plus bas) — .at(0) cible la tuile.
      await $('Financement').at(0).tap();
      await $.pumpAndSettle();

      // Assert (blocage) : pas de bouton de nouvelle demande, message explicite.
      expect($('Score insuffisant'), findsOneWidget);
      expect($('Nouvelle demande'), findsNothing);

      // Assert (redirection cours) : depuis la carte de score du tableau de
      // bord vers ScoreResultScreen, dont le bouton principal pointe vers la
      // formation tant que le score reste sous le seuil de 60
      // (`score.peutDemanderFinancement` — CDC §4.1) : c'est ce bouton précis,
      // pas celui de FinancementScreen (qui renvoie vers le formulaire de
      // score, un autre parcours), qui porte la règle T04. Financement est
      // atteint par `context.go()` (onglet du shell, pas une route empilée) :
      // retour au tableau de bord via la barre de navigation, pas un pop.
      await $('Accueil').tap();
      await $.pumpAndSettle();
      await $('Score Climat ESG').tap();
      await $.pumpAndSettle();
      expect($('Améliorer via formation'), findsOneWidget);

      await $('Améliorer via formation').tap();
      await $.pumpAndSettle();
      expect($('Formation'), findsWidgets);
    },
  );
}
