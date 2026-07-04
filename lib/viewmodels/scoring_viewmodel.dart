import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/score_climat_model.dart';
import '../repositories/score_repository.dart';

class ScoringState {
  final ScoreClimatModel? currentScore;
  final List<ScoreClimatModel> history;
  final bool isCalculating;
  final String? error;

  const ScoringState({
    this.currentScore,
    this.history = const [],
    this.isCalculating = false,
    this.error,
  });

  ScoringState copyWith({
    ScoreClimatModel? currentScore,
    List<ScoreClimatModel>? history,
    bool? isCalculating,
    String? error,
  }) {
    return ScoringState(
      currentScore: currentScore ?? this.currentScore,
      history: history ?? this.history,
      isCalculating: isCalculating ?? this.isCalculating,
      error: error,
    );
  }
}

class ScoringViewModel extends StateNotifier<ScoringState> {
  final ScoreRepository _repository;
  final String userId;

  ScoringViewModel(this._repository, this.userId) : super(const ScoringState());

  Future<void> loadLatestScore() async {
    try {
      final score = await _repository.getLatestScore(userId);
      state = state.copyWith(currentScore: score);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadHistoriqueScores() async {
    try {
      final history = await _repository.getHistory(userId);
      state = state.copyWith(history: history);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Soumet les critères au serveur pour calcul du score
  Future<ScoreClimatModel?> soumettreCriteres(Map<String, dynamic> data) async {
    state = state.copyWith(isCalculating: true);
    try {
      final score = await _repository.calculate(userId, data);
      state = state.copyWith(currentScore: score, isCalculating: false);
      return score;
    } catch (e) {
      state = state.copyWith(isCalculating: false, error: e.toString());
      return null;
    }
  }
}

final scoringViewModelProvider =
    StateNotifierProvider.family<ScoringViewModel, ScoringState, String>(
  (ref, userId) => ScoringViewModel(ScoreRepository(), userId),
);
