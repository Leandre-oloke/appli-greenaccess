// Test de non-régression de la règle 4.1 (J5.18, CDC §7.1) : le badge
// "Assuré Climat" délivré à la souscription d'une assurance (J5.13) doit
// bonifier de +10 pts le score d'éligibilité au financement (J5.14). Chaîne
// les vraies classes métier (CoursRepository → scoreEligibiliteFinancement)
// contre un FakeFirebaseFirestore partagé, même stratégie que les autres
// scénarios d'intégration de ce dossier (RGPD J3.9, T06 J4.14, messagerie
// J5.9) — pas un `integration_test/` classique contre de vrais émulateurs
// (bloqué dans ce Codespace, voir README.md §7).
//
// Les tests unitaires purs de la règle elle-même (bornes, plafond à 100)
// vivent dans test/utils/eligibilite_financement_test.dart (J5.14) ; ce
// fichier valide le scénario complet, badge réellement délivré compris.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/repositories/cours_repository.dart';
import 'package:greenaccess/utils/eligibilite_financement.dart';

Future<bool> _aBadgeAssureClimat(FakeFirebaseFirestore db, String userId) async {
  final snap = await db
      .collection('users')
      .doc(userId)
      .collection('badges')
      .doc(badgeIdAssureClimat)
      .get();
  return snap.exists;
}

void main() {
  test(
    'scénario : la souscription à une assurance délivre le badge qui bonifie ensuite '
    "l'éligibilité au financement de +10 pts, jusqu'à franchir le seuil de 60",
    () async {
      final db = FakeFirebaseFirestore();
      final repo = CoursRepository(firestore: db);
      const userId = 'alice';

      // Avant toute souscription : pas de badge, score inchangé, sous le seuil.
      var aBadge = await _aBadgeAssureClimat(db, userId);
      expect(aBadge, isFalse);
      expect(scoreEligibiliteFinancement(52, aBadgeAssureClimat: aBadge), 52);
      expect(scoreEligibiliteFinancement(52, aBadgeAssureClimat: aBadge) >= 60, isFalse);

      // L'utilisateur souscrit une assurance : le badge est réellement délivré
      // (même méthode que AssuranceRepository.soumettreDossier(), J5.13).
      await repo.triggerAssureClimatBadge(userId);

      // Le badge fait désormais franchir le seuil d'éligibilité (52 + 10 = 62).
      aBadge = await _aBadgeAssureClimat(db, userId);
      expect(aBadge, isTrue);
      final scoreBonifie = scoreEligibiliteFinancement(52, aBadgeAssureClimat: aBadge);
      expect(scoreBonifie, 62);
      expect(scoreBonifie >= 60, isTrue);
    },
  );

  test('sans le badge, un score déjà élevé n\'est pas artificiellement gonflé au-delà de 100', () async {
    final db = FakeFirebaseFirestore();
    final repo = CoursRepository(firestore: db);
    const userId = 'bob';

    await repo.triggerAssureClimatBadge(userId);
    final aBadge = await _aBadgeAssureClimat(db, userId);

    expect(scoreEligibiliteFinancement(95, aBadgeAssureClimat: aBadge), 100);
  });
}
