import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/demande_financement_model.dart';
import '../models/remboursement_model.dart';
import '../repositories/financement_repository.dart';

class SimulationFinancement {
  final double montantMin;
  final double montantMax;
  final double tauxIndicatif;
  final double scoreEligibilite;
  final List<String> organismesEligibles;

  const SimulationFinancement({
    required this.montantMin,
    required this.montantMax,
    required this.tauxIndicatif,
    required this.scoreEligibilite,
    required this.organismesEligibles,
  });
}

class FinancementState {
  final DemandeFinancementModel? currentDemande;
  final List<DemandeFinancementModel> demandes;
  final SimulationFinancement? simulation;
  final bool isLoading;
  final String? errorMessage;

  const FinancementState({
    this.currentDemande,
    this.demandes = const [],
    this.simulation,
    this.isLoading = false,
    this.errorMessage,
  });

  FinancementState copyWith({
    DemandeFinancementModel? currentDemande,
    List<DemandeFinancementModel>? demandes,
    SimulationFinancement? simulation,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FinancementState(
      currentDemande: currentDemande ?? this.currentDemande,
      demandes: demandes ?? this.demandes,
      simulation: simulation ?? this.simulation,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class FinancementViewModel extends StateNotifier<FinancementState> {
  final FinancementRepository _repository;
  final String userId;

  FinancementViewModel(this._repository, this.userId) : super(const FinancementState());

  void simuler({
    required double montant,
    required String typeProjet,
    required String secteur,
    required String pays,
  }) {
    // Simulation locale basique — le calcul précis est côté serveur
    final scoreEligibilite = _calculerEligibilite(typeProjet, secteur);
    state = state.copyWith(
      simulation: SimulationFinancement(
        montantMin: montant * 0.7,
        montantMax: montant * 1.3,
        tauxIndicatif: 5.5,
        scoreEligibilite: scoreEligibilite,
        organismesEligibles: _getOrganismesEligibles(pays, montant),
      ),
    );
  }

  double _calculerEligibilite(String typeProjet, String secteur) {
    const secteursVerts = ['agriculture', 'energie', 'recyclage', 'transport'];
    return secteursVerts.contains(secteur.toLowerCase()) ? 75.0 : 45.0;
  }

  List<String> _getOrganismesEligibles(String pays, double montant) {
    return ['AFD', 'BOAD', 'GCF', if (montant < 10000000) 'Microfinance locale'];
  }

  Future<void> soumettreDemande(DemandeFinancementModel demande) async {
    state = state.copyWith(isLoading: true);
    try {
      final submitted = await _repository.submit(demande);
      state = state.copyWith(currentDemande: submitted, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadDemandes() async {
    state = state.copyWith(isLoading: true);
    try {
      final demandes = await _repository.fetchUserDemandes(userId);
      state = state.copyWith(demandes: demandes, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<DemandeFinancementModel?> getStatut(String demandeId) async {
    return _repository.fetchStatut(demandeId);
  }

  Future<List<RemboursementModel>> getRemboursements(String demandeId) async {
    return _repository.fetchRemboursements(demandeId);
  }

  Future<void> genererEcheancier({
    required String demandeId,
    required double montantTotal,
    required int dureesMois,
    required DateTime dateDebut,
  }) async {
    await _repository.genererEcheancier(
      demandeId: demandeId,
      montantTotal: montantTotal,
      dureesMois: dureesMois,
      dateDebut: dateDebut,
    );
  }
}

final financementViewModelProvider =
    StateNotifierProvider.family<FinancementViewModel, FinancementState, String>(
  (ref, userId) => FinancementViewModel(FinancementRepository(), userId),
);
