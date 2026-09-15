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
      const paysConnus = [
        'Sénégal', 'Bénin', "Côte d'Ivoire", 'Mali', 'Burkina Faso', 'Niger', 'Togo', 'Guinée',
      ];
      for (final zone in zones) {
        expect(zone.id, isNotEmpty);
        expect(zone.nom, isNotEmpty);
        // pays (J4.10) doit correspondre à l'un des 8 pays déjà gérés par
        // l'app — utilisé pour pré-remplir la zone du simulateur par GPS.
        expect(zone.pays, isIn(paysConnus));
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

  // ── Import/gestion admin (J4.15) ────────────────────────────────────────
  group('AssuranceRepository — importDefaultZonesAlea / deleteZoneAlea', () {
    test('importDefaultZonesAlea() écrit les 16 zones bundlées dans Firestore', () async {
      final db = FakeFirebaseFirestore();
      final repo = AssuranceRepository(firestore: db);

      await repo.importDefaultZonesAlea();

      final snapshot = await db.collection('zones_alea').get();
      expect(snapshot.docs, hasLength(16));
      final dakar = snapshot.docs.firstWhere((d) => d.id == 'sn-dakar');
      expect(dakar.data()['nom'], 'Dakar');
      expect(dakar.data()['pays'], 'Sénégal');

      // Une fois importées, getZonesAlea() lit Firestore (plus de repli asset).
      final zones = await repo.getZonesAlea();
      expect(zones, hasLength(16));
    });

    test('un second import écrase proprement (pas de doublons)', () async {
      final db = FakeFirebaseFirestore();
      final repo = AssuranceRepository(firestore: db);

      await repo.importDefaultZonesAlea();
      await repo.importDefaultZonesAlea();

      final snapshot = await db.collection('zones_alea').get();
      expect(snapshot.docs, hasLength(16));
    });

    test('deleteZoneAlea() retire uniquement la zone visée', () async {
      final db = FakeFirebaseFirestore();
      final repo = AssuranceRepository(firestore: db);
      await repo.importDefaultZonesAlea();

      await repo.deleteZoneAlea('sn-dakar');

      final snapshot = await db.collection('zones_alea').get();
      expect(snapshot.docs, hasLength(15));
      expect(snapshot.docs.any((d) => d.id == 'sn-dakar'), isFalse);
      expect(snapshot.docs.any((d) => d.id == 'sn-thies'), isTrue);
    });
  });

  // ── Badge "Assuré Climat" à la souscription (J5.13) ─────────────────────
  group('AssuranceRepository — soumettreDossier', () {
    test('délivre le badge Assuré Climat au souscripteur', () async {
      final db = FakeFirebaseFirestore();
      final repo = AssuranceRepository(firestore: db);

      final contrat = await repo.soumettreDossier({
        'userId': 'alice',
        'produit_id': 'prod-1',
        'assureur_id': 'assureur-1',
        'prime_mensuelle': 5000.0,
        'zone_risque': 'sn-dakar',
      });

      expect(contrat.userId, 'alice');
      final badgeSnap =
          await db.collection('users').doc('alice').collection('badges').doc('assure_climat').get();
      expect(badgeSnap.exists, isTrue);
      expect(badgeSnap.data()?['type'], 'assurance');
      expect(badgeSnap.data()?['date_obtention'], isNotNull);
    });

    test('une seconde souscription ne recrée pas le badge (idempotent)', () async {
      final db = FakeFirebaseFirestore();
      final repo = AssuranceRepository(firestore: db);

      await repo.soumettreDossier({'userId': 'bob', 'produit_id': 'prod-1', 'assureur_id': 'a1'});
      await repo.soumettreDossier({'userId': 'bob', 'produit_id': 'prod-2', 'assureur_id': 'a1'});

      final badgesSnap = await db.collection('users').doc('bob').collection('badges').get();
      expect(badgesSnap.docs, hasLength(1));
    });
  });
}
