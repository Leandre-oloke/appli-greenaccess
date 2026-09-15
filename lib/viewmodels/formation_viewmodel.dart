import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/course_model.dart';
import '../models/lecon_model.dart';
import '../models/badge_model.dart';
import '../repositories/cours_repository.dart';
import '../utils/badge_export_formatters.dart';

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
      // J6.7 (CDC §7.1 · T10) — les 3 lectures sont indépendantes (aucune ne
      // dépend du résultat d'une autre) : les paralléliser plutôt que les
      // enchaîner en séquence réduit d'environ 3x le temps total passé en
      // aller-retour réseau au premier rendu du tableau de bord, qui
      // déclenche cette méthode dès la connexion.
      final results = await Future.wait([
        _repository.fetchAll(),
        _repository.fetchProgress(userId),
        _repository.fetchBadges(userId),
      ]);
      final courses = results[0] as List<CourseModel>;
      final progress = results[1] as List<CourseProgress>;
      final badges = results[2] as List<BadgeModel>;
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

  // ── Export des badges (J5.16, CDC §5) ─────────────────────────────────────

  String _todayStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> exporterBadgesJson() async {
    try {
      final json = buildBadgesJson(state.badges);
      final bytes = Uint8List.fromList(utf8.encode(json));
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          mimeType: 'application/json',
          name: 'greenaccess_badges_${_todayStamp()}.json',
        ),
      ]);
    } catch (e) {
      state = state.copyWith(error: 'Export impossible. Réessayez.');
    }
  }

  Future<void> exporterBadgesPdf() async {
    try {
      final bytes = await buildBadgesPdf(state.badges);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'greenaccess_badges_${_todayStamp()}.pdf',
      );
    } catch (e) {
      state = state.copyWith(error: 'Export impossible. Réessayez.');
    }
  }
}

final formationViewModelProvider =
    StateNotifierProvider.family<FormationViewModel, FormationState, String>(
  (ref, userId) => FormationViewModel(CoursRepository(), userId),
);
