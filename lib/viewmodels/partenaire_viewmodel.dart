import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/partenaire_model.dart';
import '../repositories/partenaire_repository.dart';

class PartenaireState {
  final List<PartenaireModel> partenaires;
  final bool isLoading;
  final String? error;

  const PartenaireState({
    this.partenaires = const [],
    this.isLoading = false,
    this.error,
  });

  PartenaireState copyWith({
    List<PartenaireModel>? partenaires,
    bool? isLoading,
    String? error,
  }) {
    return PartenaireState(
      partenaires: partenaires ?? this.partenaires,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PartenaireViewModel extends StateNotifier<PartenaireState> {
  final PartenaireRepository _repo;

  PartenaireViewModel(this._repo) : super(const PartenaireState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _repo.fetchAll();
      state = state.copyWith(partenaires: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> create(PartenaireModel p) async {
    try {
      final created = await _repo.create(p);
      state = state.copyWith(partenaires: [...state.partenaires, created]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> update(PartenaireModel p) async {
    try {
      await _repo.update(p);
      state = state.copyWith(
        partenaires: state.partenaires.map((x) => x.id == p.id ? p : x).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
      state = state.copyWith(
        partenaires: state.partenaires.where((x) => x.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleActif(String id, bool actif) async {
    try {
      await _repo.toggleActif(id, actif);
      state = state.copyWith(
        partenaires: state.partenaires
            .map((x) => x.id == id ? x.copyWith(actif: actif) : x)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final partenaireViewModelProvider =
    StateNotifierProvider<PartenaireViewModel, PartenaireState>(
  (ref) => PartenaireViewModel(PartenaireRepository()),
);
