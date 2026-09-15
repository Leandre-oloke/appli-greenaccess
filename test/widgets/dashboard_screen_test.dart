// Test widget de DashboardScreen (J2.21) : états "vide"/"chargé" pour le
// score et la formation, badge de notifications non lues, avertissement
// d'expiration de contrat d'assurance — sans Firebase réel (voir README.md
// §7). Même stratégie de fake que les autres tests widgets de ce dossier.
//
// Il n'y a pas d'état "erreur" visible dans l'UI de cet écran (aucun des
// ScoringState/FormationState/AssuranceState.error n'est affiché ici) : le
// test "erreur" vérifie donc la résilience — l'écran continue de s'afficher
// sans planter quand ces états portent une erreur, plutôt qu'un bandeau
// d'erreur qui n'existe pas dans le code.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:greenaccess/models/assurance_model.dart';
import 'package:greenaccess/models/score_climat_model.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/repositories/assurance_repository.dart';
import 'package:greenaccess/repositories/auth_repository.dart';
import 'package:greenaccess/repositories/cours_repository.dart';
import 'package:greenaccess/repositories/notification_repository.dart';
import 'package:greenaccess/repositories/score_repository.dart';
import 'package:greenaccess/ui/ui.dart';
import 'package:greenaccess/viewmodels/assurance_viewmodel.dart';
import 'package:greenaccess/viewmodels/auth_viewmodel.dart';
import 'package:greenaccess/viewmodels/formation_viewmodel.dart';
import 'package:greenaccess/viewmodels/notification_viewmodel.dart';
import 'package:greenaccess/viewmodels/scoring_viewmodel.dart';
import 'package:greenaccess/views/dashboard/dashboard_screen.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(auth: _MockFirebaseAuth(), firestore: FakeFirebaseFirestore());

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class _FakeAuthViewModel extends AuthViewModel {
  _FakeAuthViewModel(String userId, String nom) : super(_FakeAuthRepository()) {
    state = AuthState(
      isAuthenticated: true,
      user: UserModel(
        id: userId,
        nom: nom,
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

const _userId = 'alice';

Future<Widget> _buildDashboard({
  ScoringState scoringState = const ScoringState(),
  AssuranceState assuranceState = const AssuranceState(),
  int notificationsNonLues = 0,
  FakeFirebaseFirestore? formationDb,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final notifDb = FakeFirebaseFirestore();
  for (var i = 0; i < notificationsNonLues; i++) {
    await notifDb.collection('notifications').add({
      'titre': 'Alerte $i',
      'message': 'Message $i',
      'type': 'info',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  return ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith((ref) => _FakeAuthViewModel(_userId, 'Alice Dupont')),
      scoringViewModelProvider.overrideWith((ref, userId) {
        final vm = ScoringViewModel(
          ScoreRepository(firestore: FakeFirebaseFirestore(), functions: _MockFirebaseFunctions()),
          userId,
        );
        return vm..state = scoringState;
      }),
      // Pas d'injection d'état initial ici : DashboardScreen.initState()
      // appelle systématiquement loadCourses() (postFrameCallback), qui
      // écraserait tout de suite un état injecté à la main — on sème plutôt
      // le Firestore fake sous-jacent (formationDb) avec les données
      // attendues, pour laisser le vrai flux de chargement s'exécuter.
      formationViewModelProvider.overrideWith(
        (ref, userId) => FormationViewModel(
          CoursRepository(firestore: formationDb ?? FakeFirebaseFirestore()),
          userId,
        ),
      ),
      assuranceViewModelProvider.overrideWith((ref, userId) {
        final vm = AssuranceViewModel(AssuranceRepository(firestore: FakeFirebaseFirestore()), userId);
        return vm..state = assuranceState;
      }),
      notificationViewModelProvider.overrideWith(
        (ref, userId) => NotificationViewModel(NotificationRepository(db: notifDb), prefs, userId),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const DashboardScreen(),
    ),
  );
}

ScoreClimatModel _score(double total, NiveauScore niveau) => ScoreClimatModel(
      id: 's1',
      userId: _userId,
      scoreTotal: total,
      criteres: const ScoreCriteres(
        scoreActivite: 80,
        scoreUemoa: 100,
        scoreCo2: 60,
        scoreCertif: 50,
        scoreResilience: 80,
        bonusFormation: 5,
      ),
      niveau: niveau,
      suggestions: const [],
      dateCalcul: DateTime.now(),
      versionAlgo: 'v1-cloud',
    );

ContratAssuranceModel _contratExpirantBientot() => ContratAssuranceModel(
      id: 'c1',
      userId: _userId,
      produitId: 'p1',
      statut: StatutContrat.actif,
      assureurId: 'assureur1',
      // Contrat d'un an, souscrit il y a ~11,5 mois → expire dans ~15 jours
      // (bien à l'intérieur de la fenêtre 0-30 jours, pas pile sur la borne).
      dateDebut: DateTime.now().subtract(const Duration(days: 350)),
      primeMensuelle: 5000,
      zoneRisque: 'Vallée du Fleuve',
    );

/// Le corps du dashboard est un SliverList : au viewport par défaut du test
/// (~600px de haut), les cartes en bas (Assurance…) ne sont jamais
/// construites (virtualisation), donc introuvables via `find`. On élargit le
/// viewport pour que tout le contenu tienne sans avoir à scroller.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // _Header formate la date avec DateFormat(..., 'fr') — sans ça, ça throw
  // "Locale data has not been initialized" (fait normalement par main.dart
  // au démarrage réel de l'app, jamais exécuté dans un test widget isolé).
  setUpAll(() async {
    await initializeDateFormatting('fr', null);
  });

  testWidgets('« vide » : aucun score encore calculé affiche l\'état vide et l\'appel à l\'action',
      (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(await _buildDashboard());
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, Alice'), findsOneWidget);
    expect(find.text('Votre Score Climat'), findsOneWidget);
    expect(find.text('Calculer mon score'), findsOneWidget);
  });

  testWidgets('« chargé » : un score existant affiche la jauge et le niveau', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(await _buildDashboard(
      scoringState: ScoringState(currentScore: _score(76, NiveauScore.bon)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Score Climat ESG'), findsOneWidget);
    expect(find.text('Bon'), findsOneWidget);
    expect(find.text('Améliorer'), findsOneWidget);
  });

  testWidgets('« chargé » : la progression de formation et les XP sont affichés', (tester) async {
    _useTallViewport(tester);
    // Le Firestore fake sous-jacent est seedé directement (voir _buildDashboard) :
    // DashboardScreen déclenche lui-même loadCourses() au montage, qui ferait
    // sinon écraser tout état injecté à la main.
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 4; i++) {
      await db.collection('courses').doc('c$i').set({
        'titre': 'Cours $i',
        'theme': 'Finance climatique',
        'type': 'video',
        'duree_min': 15,
        'points_xp': 40,
        'niveau_requis': 0,
        'nb_quiz': 5,
        'actif': true,
      });
    }
    for (final entry in {'c0': 50, 'c1': 40}.entries) {
      await db
          .collection('users')
          .doc(_userId)
          .collection('progress')
          .doc(entry.key)
          .set({
        'statut': 'TERMINE',
        'score_quiz': 90,
        'points_xp_gagnés': entry.value,
        'badge_declenche': true,
      });
    }

    await tester.pumpWidget(await _buildDashboard(formationDb: db));
    await tester.pumpAndSettle();

    expect(find.text('90 XP cumulés'), findsOneWidget);
    expect(find.text('50 %'), findsOneWidget); // 2/4 cours terminés
  });

  testWidgets('le badge de notifications non lues affiche le bon décompte', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(await _buildDashboard(notificationsNonLues: 3));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets("affiche l'avertissement quand un contrat d'assurance expire bientôt",
      (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(await _buildDashboard(
      assuranceState: AssuranceState(contrats: [_contratExpirantBientot()]),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('expire bientôt'), findsOneWidget);
  });

  testWidgets(
    '« erreur » : un état error sur assurance n\'empêche pas l\'écran de s\'afficher',
    (tester) async {
      // Contrairement au score/à la formation, l'assurance n'est jamais
      // rechargée automatiquement par DashboardScreen.initState() — un état
      // error injecté ici n'est donc pas écrasé, contrairement à scoring/
      // formation (voir le test de formation ci-dessus pour ce piège).
      await tester.pumpWidget(await _buildDashboard(
        assuranceState: const AssuranceState(error: 'Erreur réseau.'),
      ));
      await tester.pumpAndSettle();

      // L'écran continue de s'afficher (pas de crash) : l'en-tête et l'état
      // vide du score restent visibles. Le dashboard n'affiche d'ailleurs
      // jamais AssuranceState.error — ce test vérifie la résilience, pas un
      // bandeau d'erreur qui n'existe pas dans le code.
      expect(find.text('Bonjour, Alice'), findsOneWidget);
      expect(find.text('Votre Score Climat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
