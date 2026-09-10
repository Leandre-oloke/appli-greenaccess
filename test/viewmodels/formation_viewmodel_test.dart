import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/models/badge_model.dart';
import 'package:greenaccess/models/course_model.dart';
import 'package:greenaccess/models/lecon_model.dart';
import 'package:greenaccess/repositories/cours_repository.dart';
import 'package:greenaccess/viewmodels/formation_viewmodel.dart';

// ── Fake repository (pas de Firestore, pas de build_runner) ─────────────────

class _FakeCoursRepository extends CoursRepository {
  List<CourseModel> courses = [];
  List<CourseProgress> progress = [];
  List<BadgeModel> badges = [];
  List<QuizQuestion> quiz = [];

  // Suivi des appels à markComplete pour les assertions
  final List<Map<String, dynamic>> markCompleteCallLog = [];

  _FakeCoursRepository() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<CourseModel>> fetchAll() async => courses;

  @override
  Future<List<CourseProgress>> fetchProgress(String userId) async => progress;

  @override
  Future<List<BadgeModel>> fetchBadges(String userId) async => badges;

  @override
  Future<List<QuizQuestion>> fetchQuiz(String courseId) async => quiz;

  @override
  Future<List<LeconModel>> fetchLecons(String courseId) async => [];

  @override
  Future<void> markComplete(
    String userId,
    String courseId,
    int scoreQuiz,
    int pointsXp,
  ) async {
    markCompleteCallLog.add({
      'userId': userId,
      'courseId': courseId,
      'scoreQuiz': scoreQuiz,
      'pointsXp': pointsXp,
    });
  }

  @override
  Future<void> triggerAssureClimatBadge(String userId) async {}
}

// ── Helpers ──────────────────────────────────────────────────────────────────

CourseModel _course({String id = 'cours_1', int xp = 10}) => CourseModel(
      id: id,
      titre: 'Agroécologie',
      theme: 'Pratiques',
      type: CourseType.video,
      dureeMin: 20,
      pointsXp: xp,
      niveauRequis: 0,
      nbQuiz: 2,
      actif: true,
    );

ProviderContainer _makeContainer(_FakeCoursRepository repo) {
  return ProviderContainer(
    overrides: [
      formationViewModelProvider('user_test').overrideWith(
        (ref) => FormationViewModel(repo, 'user_test'),
      ),
    ],
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── Badge auto-trigger ───────────────────────────────────────────────────
  group('submitQuiz — badge auto-trigger', () {
    test('score ≥ 70 : markComplete appelé avec badgeDeclenche=true (via scoreQuiz≥70)', () async {
      final repo = _FakeCoursRepository()
        ..courses = [_course()]
        ..quiz = [
          const QuizQuestion(
            id: 'q1',
            question: 'Q1',
            options: ['A', 'B'],
            correctIndex: 0,
            type: 'qcm',
          ),
        ];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(formationViewModelProvider('user_test').notifier).loadCourses();
      final questions = await container
          .read(formationViewModelProvider('user_test').notifier)
          .loadQuiz('cours_1');

      // Bonne réponse → score = 100
      await container
          .read(formationViewModelProvider('user_test').notifier)
          .submitQuiz('cours_1', [0], questions);

      expect(repo.markCompleteCallLog, hasLength(1));
      final call = repo.markCompleteCallLog.first;
      expect(call['scoreQuiz'], 100);
      expect(call['pointsXp'], 13); // 10 + 3 bonus 100%
    });

    test('score < 70 : markComplete appelé avec score 50, pas de bonus XP', () async {
      final repo = _FakeCoursRepository()
        ..courses = [_course()]
        ..quiz = [
          const QuizQuestion(
            id: 'q1', question: 'Q1',
            options: ['A', 'B'], correctIndex: 0, type: 'qcm',
          ),
          const QuizQuestion(
            id: 'q2', question: 'Q2',
            options: ['A', 'B'], correctIndex: 1, type: 'qcm',
          ),
        ];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(formationViewModelProvider('user_test').notifier).loadCourses();
      final questions = await container
          .read(formationViewModelProvider('user_test').notifier)
          .loadQuiz('cours_1');

      // answers[0]=0 correct, answers[1]=0 incorrect → 1/2 = 50
      await container
          .read(formationViewModelProvider('user_test').notifier)
          .submitQuiz('cours_1', [0, 0], questions);

      expect(repo.markCompleteCallLog, hasLength(1));
      final call = repo.markCompleteCallLog.first;
      expect(call['scoreQuiz'], 50);
      expect(call['pointsXp'], 10); // pas de bonus
    });
  });

  // ── Quiz type 'ordre' ────────────────────────────────────────────────────
  group('submitQuiz — type ordre', () {
    final ordreQuestion = const QuizQuestion(
      id: 'q_ord',
      question: 'Trier par ordre croissant',
      options: ['C', 'A', 'B'],
      correctIndex: 0,
      correctOrder: [1, 2, 0], // A, B, C
      type: 'ordre',
    );

    test('ordre correct → 100 %', () async {
      final repo = _FakeCoursRepository()
        ..courses = [_course()]
        ..quiz = [ordreQuestion];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(formationViewModelProvider('user_test').notifier).loadCourses();

      await container
          .read(formationViewModelProvider('user_test').notifier)
          .submitQuiz(
            'cours_1',
            [0],
            [ordreQuestion],
            orderAnswers: [[1, 2, 0]],
          );

      expect(repo.markCompleteCallLog.first['scoreQuiz'], 100);
    });

    test('ordre incorrect → 0 %', () async {
      final repo = _FakeCoursRepository()
        ..courses = [_course()]
        ..quiz = [ordreQuestion];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(formationViewModelProvider('user_test').notifier).loadCourses();

      await container
          .read(formationViewModelProvider('user_test').notifier)
          .submitQuiz(
            'cours_1',
            [0],
            [ordreQuestion],
            orderAnswers: [[0, 1, 2]], // mauvais ordre
          );

      expect(repo.markCompleteCallLog.first['scoreQuiz'], 0);
    });

    test('isOrderCorrect renvoie false si longueurs différentes', () {
      const q = QuizQuestion(
        id: 'q', question: 'Q',
        options: ['A', 'B', 'C'], correctIndex: 0,
        correctOrder: [1, 2, 0], type: 'ordre',
      );
      expect(q.isOrderCorrect([1, 2]), isFalse);
    });

    test('isOrderCorrect renvoie false si correctOrder vide', () {
      const q = QuizQuestion(
        id: 'q', question: 'Q',
        options: ['A', 'B'], correctIndex: 0,
        correctOrder: [], type: 'ordre',
      );
      expect(q.isOrderCorrect([0, 1]), isFalse);
    });
  });

  // ── État formation ───────────────────────────────────────────────────────
  group('état formation', () {
    test('progressPercent = 100 % quand tous les cours sont terminés', () async {
      final completedProgress = CourseProgress(
        courseId: 'cours_1',
        statut: 'TERMINE',
        scoreQuiz: 80,
        pointsXpGagnes: 10,
        badgeDeclenche: true,
      );

      final repo = _FakeCoursRepository()
        ..courses = [_course()]
        ..progress = [completedProgress];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(formationViewModelProvider('user_test').notifier).loadCourses();
      final state = container.read(formationViewModelProvider('user_test'));

      expect(state.progressPercent, 100);
      expect(state.totalXp, 10);
    });

    test('progressPercent = 0 % si aucun cours terminé', () async {
      final repo = _FakeCoursRepository()
        ..courses = [_course(), _course(id: 'cours_2')];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(formationViewModelProvider('user_test').notifier).loadCourses();
      final state = container.read(formationViewModelProvider('user_test'));

      expect(state.progressPercent, 0);
      expect(state.totalXp, 0);
    });

    test('badges chargés depuis le repo', () async {
      final badge = BadgeModel(
        id: 'badge_1',
        nom: 'Agroéco',
        description: 'Premier cours terminé',
        imageUrl: '',
        type: 'formation',
        dateObtention: DateTime(2025),
      );

      final repo = _FakeCoursRepository()
        ..courses = [_course()]
        ..badges = [badge];

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(formationViewModelProvider('user_test').notifier).loadCourses();
      final state = container.read(formationViewModelProvider('user_test'));

      expect(state.badges, hasLength(1));
      expect(state.badges.first.nom, 'Agroéco');
    });
  });
}
