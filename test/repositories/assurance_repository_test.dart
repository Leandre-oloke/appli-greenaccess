// Tests unitaires de AssuranceRepository.getZonesAlea() (Phase 4 — Carte des
// aléas climatiques) : repli sur le jeu de données bundlé
// (assets/data/zones_alea.json) quand Firestore est vide, même convention
// que CoursRepository.fetchAll() pour les cours de démo.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/repositories/assurance_repository.dart';

void main() {
  // rootBundle.loadString() a besoin d'un binding Flutter initialisé pour
  // pouvoir lire les vrais assets du projet pendant `flutter test`.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssuranceRepository — getZonesAlea', () {
    test('se replie sur assets/data/zones_alea.json quand Firestore est vide', () async {
      final repo = AssuranceRepository(firestore: FakeFirebaseFirestore());

      final zones = await repo.getZonesAlea();

      expect(zones, isNotEmpty);
      // Villes UEMOA explicitement demandées par le plan d'implémentation.
      final noms = zones.map((z) => z.nom).toSet();
      expect(noms, containsAll(['Dakar', 'Thiès', 'Saint-Louis', 'Cotonou', 'Parakou']));
      // Chaque zone est structurellement valide (pas de valeur par défaut
      // silencieuse masquant un champ manquant dans le JSON).
      for (final zone in zones) {
        expect(zone.id, isNotEmpty);
        expect(zone.nom, isNotEmpty);
        expect(zone.typeAlea, isIn(['secheresse', 'inondation', 'chaleur']));
        expect(zone.niveauRisque, isIn(['faible', 'moyen', 'eleve']));
        expect(zone.latitude, isNot(0));
        expect(zone.longitude, isNot(0));
        expect(zone.rayon, greaterThan(0));
      }
    });

    test('utilise Firestore quand des zones y sont déjà présentes (pas de repli)', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('zones_alea').doc('z1').set({
        'nom': 'Zone Firestore',
        'type_alea': 'secheresse',
        'latitude': 1.0,
        'longitude': 2.0,
        'rayon': 10.0,
        'niveau_risque': 'faible',
      });
      final repo = AssuranceRepository(firestore: db);

      final zones = await repo.getZonesAlea();

      expect(zones, hasLength(1));
      expect(zones.first.nom, 'Zone Firestore');
    });
  });
}
