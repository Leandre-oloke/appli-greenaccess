// Test widget de SimulateurAssuranceScreen (J4.10-J4.12) : ciblage GPS
// automatique de la zone, réduction de prime selon le Score Climat — sans
// Firebase réel (voir README.md §7).
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mockito/mockito.dart';

import 'package:greenaccess/models/assurance_model.dart';
import 'package:greenaccess/models/score_climat_model.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/assurance_repository.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/score_repository.dart';
import 'package:greenaccess/viewmodels/assurance_viewmodel.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/scoring_viewmodel.dart';
import 'package:greenaccess/views/assurance/simulateur_assurance_screen.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

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
        id: _userId,
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

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  LocationPermission permission;
  Position? position;

  _FakeGeolocatorPlatform({this.permission = LocationPermission.denied, this.position});

  @override
  Future<LocationPermission> checkPermission() async => permission;

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

const _userId = 'alice';

ScoreClimatModel _score(double total) => ScoreClimatModel(
      id: 's1',
      userId: _userId,
      scoreTotal: total,
      criteres: const ScoreCriteres(
        scoreActivite: 80,
        scoreUemoa: 80,
        scoreCo2: 80,
        scoreCertif: 80,
        scoreResilience: 80,
        bonusFormation: 0,
      ),
      niveau: ScoreClimatModel.niveauFromScore(total),
      suggestions: const [],
      dateCalcul: DateTime.now(),
      versionAlgo: 'v1-cloud',
    );

Widget _buildSimulateur({double? scoreClimat, List<ZoneAleaModel> zones = const []}) {
  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel()),
      assuranceViewModelProvider.overrideWith(
        (ref, userId) => AssuranceViewModel(
          AssuranceRepository(firestore: FakeFirebaseFirestore()),
          userId,
        ),
      ),
      zonesAleaProvider.overrideWith((ref) async => zones),
      scoringViewModelProvider.overrideWith((ref, userId) {
        final vm = ScoringViewModel(
          ScoreRepository(firestore: FakeFirebaseFirestore(), functions: _MockFirebaseFunctions()),
          userId,
        );
        if (scoreClimat != null) vm.state = ScoringState(currentScore: _score(scoreClimat));
        return vm;
      }),
    ],
    child: const MaterialApp(home: SimulateurAssuranceScreen()),
  );
}

void main() {
  group('Ciblage GPS automatique (J4.10)', () {
    testWidgets('permission déjà accordée : la zone la plus proche pré-remplit le champ',
        (tester) async {
      final realGeo = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
        permission: LocationPermission.whileInUse,
        position: _position(12.6392, -8.0029), // Bamako, Mali
      );
      addTearDown(() => GeolocatorPlatform.instance = realGeo);

      await tester.pumpWidget(_buildSimulateur(zones: const [
        ZoneAleaModel(
          id: 'ml-bamako',
          nom: 'Bamako',
          pays: 'Mali',
          typeAlea: 'chaleur',
          latitude: 12.6392,
          longitude: -8.0029,
          rayon: 30,
          niveauRisque: 'eleve',
        ),
        ZoneAleaModel(
          id: 'sn-dakar',
          nom: 'Dakar',
          pays: 'Sénégal',
          typeAlea: 'inondation',
          latitude: 14.6928,
          longitude: -17.4467,
          rayon: 25,
          niveauRisque: 'moyen',
        ),
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mali'), findsOneWidget);
      expect(find.text('Détectée via votre position'), findsOneWidget);
    });

    testWidgets('permission non accordée : la zone par défaut reste inchangée, pas de badge GPS',
        (tester) async {
      final realGeo = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(permission: LocationPermission.denied);
      addTearDown(() => GeolocatorPlatform.instance = realGeo);

      await tester.pumpWidget(_buildSimulateur(zones: const [
        ZoneAleaModel(
          id: 'ml-bamako',
          nom: 'Bamako',
          pays: 'Mali',
          typeAlea: 'chaleur',
          latitude: 12.6392,
          longitude: -8.0029,
          rayon: 30,
          niveauRisque: 'eleve',
        ),
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sénégal'), findsOneWidget); // valeur par défaut inchangée
      expect(find.text('Détectée via votre position'), findsNothing);
    });
  });

  group('Réduction de prime selon le Score Climat (J4.11-J4.12)', () {
    testWidgets('score excellent (95) : 25 % de réduction affichée sur le résultat',
        (tester) async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform(); // permission refusée par défaut
      await tester.pumpWidget(_buildSimulateur(scoreClimat: 95));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Calculer ma prime'));
      await tester.pump();

      expect(find.text('Réduction Score Climat'), findsOneWidget);
      expect(find.text('-25 %'), findsOneWidget);
    });

    testWidgets('aucun score calculé : aucune ligne de réduction affichée', (tester) async {
      GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
      await tester.pumpWidget(_buildSimulateur());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Calculer ma prime'));
      await tester.pump();

      expect(find.text('Réduction Score Climat'), findsNothing);
    });
  });
}
