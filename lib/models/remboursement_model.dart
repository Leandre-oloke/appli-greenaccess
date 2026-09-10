class RemboursementModel {
  final String id;
  final String demandeId;
  final int numeroEcheance;
  final DateTime dateEcheance;
  final double montant;
  final bool paye;
  final DateTime? datePaiement;

  const RemboursementModel({
    required this.id,
    required this.demandeId,
    required this.numeroEcheance,
    required this.dateEcheance,
    required this.montant,
    required this.paye,
    this.datePaiement,
  });

  factory RemboursementModel.fromFirestore(Map<String, dynamic> data, String id) {
    return RemboursementModel(
      id: id,
      demandeId: data['demandeId'] ?? '',
      numeroEcheance: data['numero_echeance'] ?? 0,
      dateEcheance: (data['date_echeance'] as dynamic).toDate(),
      montant: (data['montant'] ?? 0).toDouble(),
      paye: data['paye'] ?? false,
      datePaiement: data['date_paiement'] != null
          ? (data['date_paiement'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'demandeId': demandeId,
        'numero_echeance': numeroEcheance,
        'date_echeance': dateEcheance,
        'montant': montant,
        'paye': paye,
        'date_paiement': datePaiement,
      };
}
