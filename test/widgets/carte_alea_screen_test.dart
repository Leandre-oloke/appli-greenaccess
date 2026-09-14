// Test widget de CarteAleaScreen (J4.4-J4.13) : fond de carte OpenStreetMap,
// marqueurs/cercles de risque colorés par type d'aléa, position GPS de
// l'utilisateur, feuille de produits d'assurance éligibles au tap sur une
// zone — sans Firebase réel (voir README.md §7) ni accès réseau réel aux
// tuiles OpenStreetMap (non nécessaire : ce test vérifie la structure du
// widget, pas le rendu visuel des tuiles).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'package:greenaccess/models/assurance_model.dart';
import 'package:greenaccess/viewmodels/assurance_viewmodel.dart';
import 'package:greenaccess/views/assurance/carte_alea_screen.dart';

/// Plateforme geolocator factice — évite tout appel de canal de plateforme
/// réel (indisponible en test) en substituant directement
/// `GeolocatorPlatform.instance`.
class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  LocationPermission permission;
  Position? position;

  _FakeGeolocatorPlatform({this.permission = LocationPermission.always, this.position});

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (position == null) throw Exception('Position indisponible');
    return position!;
  }
}

Position _position(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

ProduitAssuranceModel _produit(String libelle) => ProduitAssuranceModel(
      id: libelle,
      libelle: libelle,
      type: 'multirisques',
      description: 'Produit de test',
      conditions: 'Score Climat ≥ 45',
      primeMin: 3000,
      primeMax: 15000,
      zonesEligibles: const [],
      indiceDeclencheur: 'Indice test',
    );

Widget _buildCarte({
  List<ZoneAleaModel> zones = const [],
  Map<String, List<ProduitAssuranceModel>> produitsParZone = const {},
}) {
  return ProviderScope(
    overrides: [
      zonesAleaProvider.overrideWith((ref) async => zones),
      for (final entry in produitsParZone.entries)
        produitsParZoneProvider(entry.key).overrideWith((ref) async => entry.value),
    ],
    child: const MaterialApp(home: CarteAleaScreen()),
  );
}

void main() {
  testWidgets('affiche la carte, la légende et un marqueur par zone', (tester) async {
    await tester.pumpWidget(_buildCarte(zones: const [
      ZoneAleaModel(
        id: 'z1',
        nom: 'Dakar',
        typeAlea: 'inondation',
        latitude: 14.6928,
        longitude: -17.4467,
        rayon: 25,
        niveauRisque: 'moyen',
      ),
      ZoneAleaModel(
        id: 'z2',
        nom: 'Bamako',
        typeAlea: 'chaleur',
        latitude: 12.6392,
        longitude: -8.0029,
        rayon: 30,
        niveauRisque: 'eleve',
      ),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Carte des aléas climatiques'), findsOneWidget);
    // Couvre explicitement le rendu de la carte elle-même (J4.13), pas
    // seulement son contenu (marqueurs/légende) : fond OpenStreetMap et les
    // deux couches de superposition sont bien montés dans l'arbre.
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsOneWidget);
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
    // Les marqueurs sont identifiés par le message unique de leur Tooltip
    // (« Ville — Type ») plutôt que par icône : la légende réutilise les
    // mêmes icônes que les marqueurs, et flutter_map peut dessiner plusieurs
    // copies d'un même marqueur (répétition horizontale de la carte à faible
    // zoom) — un find.byIcon() compterait donc à tort les deux.
    expect(find.byTooltip('Dakar — Inondation'), findsWidgets);
    expect(find.byTooltip('Bamako — Chaleur'), findsWidgets);
    // Légende : les 3 types d'aléa sont toujours listés, indépendamment des
    // zones réellement chargées.
    expect(find.text('Sécheresse'), findsOneWidget);
    expect(find.text('Inondation'), findsOneWidget);
    expect(find.text('Chaleur'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets(
    'taper sur un marqueur ouvre la feuille des produits éligibles (J4.9)',
    (tester) async {
      await tester.pumpWidget(_buildCarte(
        zones: const [
          ZoneAleaModel(
            id: 'z1',
            nom: 'Saint-Louis',
            typeAlea: 'inondation',
            latitude: 16.0179,
            longitude: -16.4896,
            rayon: 20,
            niveauRisque: 'eleve',
          ),
        ],
        produitsParZone: {
          'Saint-Louis': [_produit('Assurance Inondation Fleuve')],
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Saint-Louis — Inondation').first);
      await tester.pumpAndSettle();

      expect(find.text('Saint-Louis'), findsOneWidget);
      expect(find.textContaining('Risque eleve'), findsOneWidget);
      expect(find.text('Produits d\'assurance éligibles'), findsOneWidget);
      expect(find.text('Assurance Inondation Fleuve'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Simuler'), findsOneWidget);
    },
  );

  testWidgets(
    'zone sans produit éligible : affiche un état vide avec un lien vers tous les produits',
    (tester) async {
      await tester.pumpWidget(_buildCarte(
        zones: const [
          ZoneAleaModel(
            id: 'z1',
            nom: 'Niamey',
            typeAlea: 'chaleur',
            latitude: 13.5127,
            longitude: 2.1128,
            rayon: 35,
            niveauRisque: 'eleve',
          ),
        ],
        produitsParZone: const {'Niamey': []},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Niamey — Chaleur').first);
      await tester.pumpAndSettle();

      expect(find.text('Aucun produit éligible pour cette zone pour le moment.'),
          findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Voir tous les produits'), findsOneWidget);
    },
  );

  testWidgets('bouton de localisation : position affichée quand la permission est accordée',
      (tester) async {
    final realGeo = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      permission: LocationPermission.whileInUse,
      position: _position(14.0, -16.0),
    );
    addTearDown(() => GeolocatorPlatform.instance = realGeo);

    await tester.pumpWidget(_buildCarte());
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // findsWidgets (pas findsOneWidget) : flutter_map peut dessiner plusieurs
    // copies d'un même marqueur (répétition horizontale de la carte à
    // faible zoom) — seule l'absence totale (0) serait un signal d'échec.
    expect(find.byIcon(Icons.person_pin_circle), findsWidgets);
  });

  testWidgets('bouton de localisation : message d\'erreur si la permission est refusée',
      (tester) async {
    final realGeo = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(permission: LocationPermission.denied);
    addTearDown(() => GeolocatorPlatform.instance = realGeo);

    await tester.pumpWidget(_buildCarte());
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Permission de localisation refusée.'), findsOneWidget);
    expect(find.byIcon(Icons.person_pin_circle), findsNothing);
  });
}
