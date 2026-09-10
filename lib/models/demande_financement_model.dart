import 'package:cloud_firestore/cloud_firestore.dart';

enum StatutDemande { brouillon, soumis, enExamen, approuve, rejete, finance }

class DemandeFinancementModel {
  final String id;
  final String userId;
  final DateTime dateSoumission;
  final double montant;
  final String typeProjet;
  final String secteur;
  final String pays;
  final String descriptionProjet;
  final StatutDemande statut;
  final double scoreEligibilite;
  final List<String> docsUrl;
  final String? partenaireId;
  final String? commentaireRejet;
  final String alignementTaxonomie; // Conforme, Partiel, NonConforme

  const DemandeFinancementModel({
    required this.id,
    required this.userId,
    required this.dateSoumission,
    required this.montant,
    required this.typeProjet,
    required this.secteur,
    required this.pays,
    required this.descriptionProjet,
    required this.statut,
    required this.scoreEligibilite,
    required this.docsUrl,
    this.partenaireId,
    this.commentaireRejet,
    required this.alignementTaxonomie,
  });

  factory DemandeFinancementModel.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime dateSoumission;
    try {
      dateSoumission = (data['date_soumission'] as Timestamp).toDate();
    } catch (_) {
      dateSoumission = DateTime.now();
    }
    return DemandeFinancementModel(
      id: id,
      userId: data['userId'] ?? '',
      dateSoumission: dateSoumission,
      montant: (data['montant'] ?? 0).toDouble(),
      typeProjet: data['type_projet'] ?? '',
      secteur: data['secteur'] ?? '',
      pays: data['pays'] ?? '',
      descriptionProjet: data['description_projet'] ?? '',
      statut: StatutDemande.values.firstWhere(
        (s) => s.name == (data['statut'] ?? 'brouillon'),
        orElse: () => StatutDemande.brouillon,
      ),
      scoreEligibilite: (data['score_eligibilite'] ?? 0).toDouble(),
      docsUrl: List<String>.from(data['docs_url'] ?? []),
      partenaireId: data['partenaire_id'],
      commentaireRejet: data['commentaire_rejet'],
      alignementTaxonomie: data['alignement_taxonomie'] ?? 'NonConforme',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'date_soumission': Timestamp.fromDate(dateSoumission),
        'montant': montant,
        'type_projet': typeProjet,
        'secteur': secteur,
        'pays': pays,
        'description_projet': descriptionProjet,
        'statut': statut.name,
        'score_eligibilite': scoreEligibilite,
        'docs_url': docsUrl,
        'partenaire_id': partenaireId,
        'commentaire_rejet': commentaireRejet,
        'alignement_taxonomie': alignementTaxonomie,
      };
}
