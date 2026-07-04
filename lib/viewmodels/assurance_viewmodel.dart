import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assurance_model.dart';
import '../repositories/assurance_repository.dart';

class AssuranceState {
  final List<ProduitAssuranceModel> produits;
  final List<ContratAssuranceModel> contrats;
  final List<ZoneAleaModel> zonesAlea;
  final SimulationAssuranceResult? simulation;
  final ContratAssuranceModel? contratActif;
  final bool isLoading;
  final String? error;

  const AssuranceState({
    this.produits = const [],
    this.contrats = const [],
    this.zonesAlea = const [],
    this.simulation,
    this.contratActif,
    this.isLoading = false,
    this.error,
  });

  AssuranceState copyWith({
    List<ProduitAssuranceModel>? produits,
    List<ContratAssuranceModel>? contrats,
    List<ZoneAleaModel>? zonesAlea,
    SimulationAssuranceResult? simulation,
    ContratAssuranceModel? contratActif,
    bool? isLoading,
    String? error,
  }) {
    return AssuranceState(
      produits: produits ?? this.produits,
      contrats: contrats ?? this.contrats,
      zonesAlea: zonesAlea ?? this.zonesAlea,
      simulation: simulation ?? this.simulation,
      contratActif: contratActif ?? this.contratActif,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AssuranceViewModel extends StateNotifier<AssuranceState> {
  final AssuranceRepository _repository;
  final String userId;

  AssuranceViewModel(this._repository, this.userId) : super(const AssuranceState());

  Future<void> loadProduitsParZone(String zone) async {
    state = state.copyWith(isLoading: true);
    try {
      final produits = await _repository.getProduitsParZone(zone);
      final zonesAlea = await _repository.getZonesAlea();
      state = state.copyWith(produits: produits, zonesAlea: zonesAlea, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void simulerPrime({
    required String zone,
    required String typeAlea,
    required double superficieCultivee,
    required double valeurAssurable,
  }) {
    final ProduitAssuranceModel produit;
    if (state.produits.isNotEmpty) {
      produit = state.produits.firstWhere(
        (p) => p.type == typeAlea,
        orElse: () => state.produits.first,
      );
    } else {
      produit = ProduitAssuranceModel(
        id: 'default_$typeAlea',
        libelle: 'Assurance ${_typeLabel(typeAlea)}',
        type: typeAlea,
        description: 'Protection paramétrique contre les risques de ${_typeLabel(typeAlea)}.',
        conditions: 'Score Climat ≥ 45',
        primeMin: _basePrime(typeAlea),
        primeMax: _basePrime(typeAlea) * 5,
        zonesEligibles: [zone],
        indiceDeclencheur: 'Indice paramétrique satellite',
      );
    }
    final facteur = (superficieCultivee / 2.0).clamp(0.5, 4.0);
    final prime = produit.primeMin * facteur;
    final indemnisation = valeurAssurable * 0.8;
    state = state.copyWith(
      simulation: SimulationAssuranceResult(
        produitRecommande: produit,
        primeEstimee: prime,
        indemnisationEstimee: indemnisation,
        raisonRecommandation: 'Produit adapté à votre zone ($zone) pour les risques de ${_typeLabel(typeAlea)}. '
            'Prime calculée sur ${superficieCultivee.toStringAsFixed(1)} ha.',
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'secheresse' => 'sécheresse',
        'inondation' => 'inondation',
        'chaleur' => 'stress thermique',
        _ => 'multirisques',
      };

  double _basePrime(String type) => switch (type) {
        'secheresse' => 5000,
        'inondation' => 4000,
        'chaleur' => 3000,
        _ => 10000,
      };

  Future<void> soumettreSouscription(Map<String, dynamic> dossier) async {
    state = state.copyWith(isLoading: true);
    try {
      final contrat = await _repository.soumettreDossier({...dossier, 'userId': userId});
      state = state.copyWith(contratActif: contrat, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadContrats() async {
    state = state.copyWith(isLoading: true);
    try {
      final contrats = await _repository.getContrats(userId);
      final actif = contrats.where((c) => c.statut == StatutContrat.actif).firstOrNull;
      state = state.copyWith(contrats: contrats, contratActif: actif, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final assuranceViewModelProvider =
    StateNotifierProvider.family<AssuranceViewModel, AssuranceState, String>(
  (ref, userId) => AssuranceViewModel(AssuranceRepository(), userId),
);
