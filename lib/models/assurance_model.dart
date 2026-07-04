enum StatutContrat { soumis, actif, expire, sinistre }

class ProduitAssuranceModel {
  final String id;
  final String libelle;
  final String type;
  final String description;
  final String conditions;
  final double primeMin;
  final double primeMax;
  final List<String> zonesEligibles;
  final String indiceDeclencheur;

  const ProduitAssuranceModel({
    required this.id,
    required this.libelle,
    required this.type,
    required this.description,
    required this.conditions,
    required this.primeMin,
    required this.primeMax,
    required this.zonesEligibles,
    required this.indiceDeclencheur,
  });

  factory ProduitAssuranceModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ProduitAssuranceModel(
      id: id,
      libelle: data['libelle'] ?? '',
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      conditions: data['conditions'] ?? '',
      primeMin: (data['prime_min'] ?? 0).toDouble(),
      primeMax: (data['prime_max'] ?? 0).toDouble(),
      zonesEligibles: List<String>.from(data['zones_eligibles'] ?? []),
      indiceDeclencheur: data['indice_declencheur'] ?? '',
    );
  }
}

class ContratAssuranceModel {
  final String id;
  final String userId;
  final String produitId;
  final StatutContrat statut;
  final String assureurId;
  final DateTime dateDebut;
  final double primeMensuelle;
  final String zoneRisque;

  const ContratAssuranceModel({
    required this.id,
    required this.userId,
    required this.produitId,
    required this.statut,
    required this.assureurId,
    required this.dateDebut,
    required this.primeMensuelle,
    required this.zoneRisque,
  });

  factory ContratAssuranceModel.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime dateDebut;
    try {
      dateDebut = (data['date_debut'] as dynamic).toDate();
    } catch (_) {
      dateDebut = DateTime.now();
    }
    return ContratAssuranceModel(
      id: id,
      userId: data['userId'] ?? '',
      produitId: data['produit_id'] ?? '',
      statut: StatutContrat.values.firstWhere(
        (s) => s.name == (data['statut'] ?? 'soumis'),
        orElse: () => StatutContrat.soumis,
      ),
      assureurId: data['assureur_id'] ?? '',
      dateDebut: dateDebut,
      primeMensuelle: (data['prime_mensuelle'] ?? 0).toDouble(),
      zoneRisque: data['zone_risque'] ?? '',
    );
  }
}

class SimulationAssuranceResult {
  final ProduitAssuranceModel produitRecommande;
  final double primeEstimee;
  final double indemnisationEstimee;
  final String raisonRecommandation;

  const SimulationAssuranceResult({
    required this.produitRecommande,
    required this.primeEstimee,
    required this.indemnisationEstimee,
    required this.raisonRecommandation,
  });
}

class ZoneAleaModel {
  final String id;
  final String nom;
  final String typeAlea; // secheresse, inondation, chaleur
  final double latitude;
  final double longitude;
  final double rayon; // km
  final String niveauRisque; // faible, moyen, eleve

  const ZoneAleaModel({
    required this.id,
    required this.nom,
    required this.typeAlea,
    required this.latitude,
    required this.longitude,
    required this.rayon,
    required this.niveauRisque,
  });

  factory ZoneAleaModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ZoneAleaModel(
      id: id,
      nom: data['nom'] ?? '',
      typeAlea: data['type_alea'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      rayon: (data['rayon'] ?? 0).toDouble(),
      niveauRisque: data['niveau_risque'] ?? 'faible',
    );
  }
}
