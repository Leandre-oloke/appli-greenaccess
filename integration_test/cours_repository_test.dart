// Test d'intégration CoursRepository contre les émulateurs Firebase
// (Auth + Firestore), via le package `integration_test` officiel.
// Actuellement bloqué en exécution — voir auth_repository_test.dart (même
// dossier) pour le diagnostic complet, et README.md §7.
//
// Les scénarios ici restent volontairement sur les écritures qu'un
// utilisateur standard peut faire lui-même (progression, badges) : écrire un
// cours dans `courses/` exige le rôle admin (firestore.rules), ce qui
// soulève une question de sécurité distincte (voir note dans le README sur
// la règle de création `users/{uid}` — un compte peut aujourd'hui se
// déclarer admin dès sa création) qui n'est pas dans le périmètre de ce test.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:greenaccess/firebase_options.dart';
import 'package:greenaccess/repositories/cours_repository.dart';

const _emulatorHost = 'localhost';

String _uniqueEmail(String tag) =>
    '$tag-${DateTime.now().microsecondsSinceEpoch}@greenaccess.test';

Future<String> _signUp(String tag) async {
  final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: _uniqueEmail(tag),
    password: 'MotDePasse123!',
  );
  return credential.user!.uid;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late CoursRepository repo;

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8085);
    repo = CoursRepository(firestore: FirebaseFirestore.instance);
  });

  setUp(() async {
    await FirebaseAuth.instance.signOut();
  });

  test('fetchAll() renvoie les cours de démo quand Firestore est vide', () async {
    await _signUp('fetchall');
    final courses = await repo.fetchAll();
    expect(courses.length, 5);
    expect(courses.map((c) => c.id), contains('demo-1'));
  });

  test('fetchById() sur un cours inexistant renvoie null', () async {
    await _signUp('fetchbyid');
    final course = await repo.fetchById('cours-qui-nexiste-pas');
    expect(course, isNull);
  });

  test('fetchQuiz() et fetchLecons() sur un cours inexistant renvoient des listes vides', () async {
    await _signUp('fetchquiz');
    expect(await repo.fetchQuiz('cours-qui-nexiste-pas'), isEmpty);
    expect(await repo.fetchLecons('cours-qui-nexiste-pas'), isEmpty);
  });

  test(
    'markComplete() avec un score ≥70 enregistre la progression ET déclenche un badge',
    () async {
      final userId = await _signUp('markcomplete-badge');

      await repo.markComplete(userId, 'demo-1', 85, 50);

      final progress = await repo.fetchProgress(userId);
      expect(progress.length, 1);
      expect(progress.first.courseId, 'demo-1');
      expect(progress.first.statut, 'TERMINE');
      expect(progress.first.scoreQuiz, 85);
      expect(progress.first.pointsXpGagnes, 50);
      expect(progress.first.badgeDeclenche, isTrue);

      final badges = await repo.fetchBadges(userId);
      expect(badges, isNotEmpty);
      expect(badges.any((b) => b.type == 'formation'), isTrue);
    },
  );

  test('markComplete() avec un score <70 ne déclenche pas de badge', () async {
    final userId = await _signUp('markcomplete-nobadge');

    await repo.markComplete(userId, 'demo-2', 50, 20);

    final progress = await repo.fetchProgress(userId);
    expect(progress.first.badgeDeclenche, isFalse);

    final badges = await repo.fetchBadges(userId);
    expect(badges, isEmpty);
  });

  test('triggerAssureClimatBadge() est idempotent (pas de doublon au 2e appel)', () async {
    final userId = await _signUp('assureclimat');

    await repo.triggerAssureClimatBadge(userId);
    await repo.triggerAssureClimatBadge(userId);

    final badges = await repo.fetchBadges(userId);
    final assureClimatBadges = badges.where((b) => b.type == 'assurance');
    expect(assureClimatBadges.length, 1);
  });
}
