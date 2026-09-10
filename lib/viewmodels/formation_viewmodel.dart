import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course_model.dart';
import '../models/lecon_model.dart';
import '../models/badge_model.dart';
import '../repositories/cours_repository.dart';

class FormationState {
  final List<CourseModel> courses;
  final List<CourseProgress> progress;
  final List<BadgeModel> badges;
  final Map<String, List<LeconModel>> leconsByCourse;
  final bool isLoading;
  final String? error;

  const FormationState({
    this.courses = const [],
    this.progress = const [],
    this.badges = const [],
    this.leconsByCourse = const {},
    this.isLoading = false,
    this.error,
  });

  int get progressPercent {
    if (courses.isEmpty) return 0;
    final done = progress.where((p) => p.isComplete).length;
    return ((done / courses.length) * 100).round();
  }

  int get totalXp => progress.fold(0, (sum, p) => sum + p.pointsXpGagnes);

  FormationState copyWith({
    List<CourseModel>? courses,
    List<CourseProgress>? progress,
    List<BadgeModel>? badges,
    Map<String, List<LeconModel>>? leconsByCourse,
    bool? isLoading,
    String? error,
  }) {
    return FormationState(
      courses: courses ?? this.courses,
      progress: progress ?? this.progress,
      badges: badges ?? this.badges,
      leconsByCourse: leconsByCourse ?? this.leconsByCourse,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class FormationViewModel extends StateNotifier<FormationState> {
  final CoursRepository _repository;
  final String userId;

  FormationViewModel(this._repository, this.userId) : super(const FormationState());

  Future<void> loadCourses() async {
    state = state.copyWith(isLoading: true);
    try {
      final courses = await _repository.fetchAll();
      final progress = await _repository.fetchProgress(userId);
      final badges = await _repository.fetchBadges(userId);
      state = state.copyWith(
        courses: courses,
        progress: progress,
        badges: badges,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<QuizQuestion>> loadQuiz(String courseId) async {
    return _repository.fetchQuiz(courseId);
  }

  Future<void> submitQuiz(
    String courseId,
    List<int> answers,
    List<QuizQuestion> questions, {
    List<List<int>> orderAnswers = const [],
  }) async {
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (q.type == 'ordre') {
        if (orderAnswers.length > i && q.isOrderCorrect(orderAnswers[i])) correct++;
      } else {
        if (answers[i] == q.correctIndex) correct++;
      }
    }
    final score = questions.isEmpty ? 0 : ((correct / questions.length) * 100).round();
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final bonusXp = score == 100 ? course.pointsXp + 3 : course.pointsXp;
    await _repository.markComplete(userId, courseId, score, bonusXp);
    await loadCourses();
  }

  Future<void> loadLecons(String courseId) async {
    final lecons = await _repository.fetchLecons(courseId);
    final updated = Map<String, List<LeconModel>>.from(state.leconsByCourse);
    updated[courseId] = lecons;
    state = state.copyWith(leconsByCourse: updated);
  }

  Future<void> trackProgress(String courseId) async {
    await loadCourses();
  }
}

final formationViewModelProvider =
    StateNotifierProvider.family<FormationViewModel, FormationState, String>(
  (ref, userId) => FormationViewModel(CoursRepository(), userId),
);
