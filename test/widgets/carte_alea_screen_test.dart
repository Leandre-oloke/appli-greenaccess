// Test widget de CarteAleaScreen (J4.4-J4.6) : fond de carte OpenStreetMap,
// marqueurs/cercles de risque colorés par type d'aléa, position GPS de
// l'utilisateur — sans Firebase réel (voir README.md §7) ni accès réseau réel
// aux tuiles OpenStreetMap (non nécessaire : ce test vérifie la structure du
// widget, pas le rendu visuel des tuiles).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/assurance_model.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/assurance_repository.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/viewmodels/assurance_viewmodel.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/views/assurance/carte_alea_screen.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(auth: _MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class _FakeAuthViewModel extends AuthViewModel {
  _FakeAuthViewModel() : super(_FakeAuthRepository()) {
    state = AuthState(
      isAuthenticated: true,
      user: UserModel(
        id: 'alice',
        nom: 'Alice',
        email: 'alice@greenaccess.test',
        telephone: '',
        pays: 'Sénégal',
        region: 'Dakar',
        secteur: 'Agriculture',
        dateInscription: DateTime.now(),
        profilComplet: true,
        role: UserRole.user,
      ),
    );
  }
}

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

Widget _buildCarte(AssuranceState assuranceState) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel()),
      assuranceViewModelProvider.overrideWith((ref, userId) {
        final vm = AssuranceViewModel(
          AssuranceRepository(firestore: FakeFirebaseFirestore()),
          userId,
        );
        return vm..state = assuranceState;
      }),
    ],
    child: const MaterialApp(home: CarteAleaScreen()),
  );
}

void main() {
  testWidgets('affiche la carte, la légende et un marqueur par zone', (tester) async {
    await tester.pumpWidget(_buildCarte(AssuranceState(zonesAlea: [
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
    ])));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Carte des aléas climatiques'), findsOneWidget);
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

  testWidgets('taper sur un marqueur affiche le nom et le risque de la zone', (tester) async {
    await tester.pumpWidget(_buildCarte(AssuranceState(zonesAlea: [
      ZoneAleaModel(
        id: 'z1',
        nom: 'Saint-Louis',
        typeAlea: 'inondation',
        latitude: 16.0179,
        longitude: -16.4896,
        rayon: 20,
        niveauRisque: 'eleve',
      ),
    ])));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Saint-Louis — Inondation').first);
    await tester.pump();

    expect(find.textContaining('Saint-Louis'), findsWidgets);
    expect(find.textContaining('eleve'), findsWidgets);
  });

  testWidgets('bouton de localisation : position affichée quand la permission est accordée',
      (tester) async {
    final realGeo = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      permission: LocationPermission.whileInUse,
      position: _position(14.0, -16.0),
    );
    addTearDown(() => GeolocatorPlatform.instance = realGeo);

    await tester.pumpWidget(_buildCarte(const AssuranceState()));
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

    await tester.pumpWidget(_buildCarte(const AssuranceState()));
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Permission de localisation refusée.'), findsOneWidget);
    expect(find.byIcon(Icons.person_pin_circle), findsNothing);
  });
}
