// Tests unitaires purs de scoreEligibiliteFinancement (J5.14, CDC §4.1 —
// règle d'incitation croisée : le badge Assuré Climat bonifie le score
// d'éligibilité au financement de +10 pts).
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/utils/eligibilite_financement.dart';

void main() {
  group('scoreEligibiliteFinancement', () {
    test('sans le badge, le score est inchangé', () {
      expect(scoreEligibiliteFinancement(55, aBadgeAssureClimat: false), 55);
    });

    test('avec le badge, +10 pts sont ajoutés', () {
      expect(scoreEligibiliteFinancement(55, aBadgeAssureClimat: true), 65);
    });

    test('le bonus peut faire franchir le seuil d\'éligibilité (60)', () {
      expect(scoreEligibiliteFinancement(52, aBadgeAssureClimat: true), 62);
      expect(scoreEligibiliteFinancement(52, aBadgeAssureClimat: false), 52);
    });

    test('le score reste plafonné à 100 même avec le bonus', () {
      expect(scoreEligibiliteFinancement(95, aBadgeAssureClimat: true), 100);
    });
  });
}
