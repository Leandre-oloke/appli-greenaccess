// Test d'intégration (J4.14, CDC §7.1 · T06) : valide bout en bout le
// scénario « zone à risque élevé sur la carte → produit paramétrique
// recommandé », en tenant compte du Score Climat (J4.11-J4.12).
//
// Comme pour le scénario RGPD de J3.9
// (test/integration/rgpd_export_deletion_scenario_test.dart), ce n'est pas un
// `integration_test/` Flutter classique contre de vrais émulateurs — bloqué
// dans ce Codespace (voir README.md §7). Le scénario T06 est validé avec les
// vraies classes métier (ExportRepository/AssuranceRepository/
// AssuranceViewModel), enchaînées dans l'ordre du parcours utilisateur réel :
// carte → zone → simulation, contre les données bundlées
// (assets/data/zones_alea.json) qui alimentent réellement la carte tant que
// Firestore n'est pas peuplé.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/repositories/assurance_repository.dart';
import 'package:greenaccess/viewmodels/assurance_viewmodel.dart';

const _userId = 'alice';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'zone à risque élevé sur la carte → produit paramétrique recommandé, prime réduite par le Score Climat',
    () async {
      final repo = AssuranceRepository(firestore: FakeFirebaseFirestore());

      // ── 1. La carte affiche les zones — on y repère une zone à risque élevé ──
      final zones = await repo.getZonesAlea();
      final zoneRisqueEleve = zones.firstWhere((z) => z.niveauRisque == 'eleve');
      expect(zoneRisqueEleve.pays, isNotEmpty);
      expect(zoneRisqueEleve.typeAlea, isNotEmpty);

      // ── 2. L'utilisateur simule une assurance pour cette zone/ce risque ─────
      final container = ProviderContainer(overrides: [
        assuranceViewModelProvider(_userId).overrideWith((ref) => AssuranceViewModel(repo, _userId)),
      ]);
      addTearDown(container.dispose);
      final vm = container.read(assuranceViewModelProvider(_userId).notifier);

      // Aucun produit_assurance seedé en Firestore (pas encore d'outil admin
      // pour les peupler) : le ViewModel synthétise un produit paramétrique
      // adapté au type d'aléa — comportement réel de l'app aujourd'hui.
      vm.simulerPrime(
        zone: zoneRisqueEleve.pays,
        typeAlea: zoneRisqueEleve.typeAlea,
        superficieCultivee: 2.0,
        valeurAssurable: 1000000,
        scoreClimat: 85, // excellent → réduction maximale (J4.11-J4.12)
      );

      final simulation = container.read(assuranceViewModelProvider(_userId)).simulation;
      expect(simulation, isNotNull);

      // ── 3. Le produit recommandé est bien paramétrique et adapté à la zone ──
      expect(simulation!.produitRecommande.indiceDeclencheur, contains('paramétrique'));
      expect(simulation.produitRecommande.type, zoneRisqueEleve.typeAlea);
      expect(simulation.produitRecommande.zonesEligibles, contains(zoneRisqueEleve.pays));

      // ── 4. Le Score Climat a bien réduit la prime (T06 relie score et prime) ─
      expect(simulation.remiseScorePct, 25);

      vm.simulerPrime(
        zone: zoneRisqueEleve.pays,
        typeAlea: zoneRisqueEleve.typeAlea,
        superficieCultivee: 2.0,
        valeurAssurable: 1000000,
        // Pas de score cette fois : sert de référence pour comparer la prime.
      );
      final simulationSansScore = container.read(assuranceViewModelProvider(_userId)).simulation!;
      expect(simulation.primeEstimee, lessThan(simulationSansScore.primeEstimee));
    },
  );
}
