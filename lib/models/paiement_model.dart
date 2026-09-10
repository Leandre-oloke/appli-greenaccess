enum OperateurMobileMoney { wave, orangeMoney, mtnMomo, moov, free }

enum StatutPaiement { enAttente, confirme, echoue, annule }

class PaiementModel {
  final String id;
  final String demandeId;
  final String echeanceId;
  final String userId;
  final double montant;
  final OperateurMobileMoney operateur;
  final StatutPaiement statut;
  final String reference;
  final DateTime dateCreation;
  final DateTime? dateConfirmation;

  const PaiementModel({
    required this.id,
    required this.demandeId,
    required this.echeanceId,
    required this.userId,
    required this.montant,
    required this.operateur,
    required this.statut,
    required this.reference,
    required this.dateCreation,
    this.dateConfirmation,
  });

  factory PaiementModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PaiementModel(
      id: id,
      demandeId: data['demandeId'] ?? '',
      echeanceId: data['echeanceId'] ?? '',
      userId: data['userId'] ?? '',
      montant: (data['montant'] ?? 0).toDouble(),
      operateur: OperateurMobileMoney.values.firstWhere(
        (o) => o.name == data['operateur'],
        orElse: () => OperateurMobileMoney.wave,
      ),
      statut: StatutPaiement.values.firstWhere(
        (s) => s.name == data['statut'],
        orElse: () => StatutPaiement.enAttente,
      ),
      reference: data['reference'] ?? '',
      dateCreation: (data['date_creation'] as dynamic).toDate(),
      dateConfirmation: data['date_confirmation'] != null
          ? (data['date_confirmation'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'demandeId': demandeId,
        'echeanceId': echeanceId,
        'userId': userId,
        'montant': montant,
        'operateur': operateur.name,
        'statut': statut.name,
        'reference': reference,
        'date_creation': dateCreation,
        'date_confirmation': dateConfirmation,
      };
}
