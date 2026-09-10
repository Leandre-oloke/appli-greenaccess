class PartenaireModel {
  final String id;
  final String nom;
  final String type;
  final String description;
  final String contact;
  final List<String> pays;
  final double montantMin;
  final double montantMax;
  final bool actif;

  const PartenaireModel({
    required this.id,
    required this.nom,
    required this.type,
    required this.description,
    required this.contact,
    required this.pays,
    required this.montantMin,
    required this.montantMax,
    this.actif = true,
  });

  factory PartenaireModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PartenaireModel(
      id: id,
      nom: data['nom'] ?? '',
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      contact: data['contact'] ?? '',
      pays: List<String>.from(data['pays'] ?? []),
      montantMin: (data['montant_min'] ?? 0).toDouble(),
      montantMax: (data['montant_max'] ?? 0).toDouble(),
      actif: data['actif'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nom': nom,
        'type': type,
        'description': description,
        'contact': contact,
        'pays': pays,
        'montant_min': montantMin,
        'montant_max': montantMax,
        'actif': actif,
      };

  PartenaireModel copyWith({
    String? nom,
    String? type,
    String? description,
    String? contact,
    List<String>? pays,
    double? montantMin,
    double? montantMax,
    bool? actif,
  }) {
    return PartenaireModel(
      id: id,
      nom: nom ?? this.nom,
      type: type ?? this.type,
      description: description ?? this.description,
      contact: contact ?? this.contact,
      pays: pays ?? this.pays,
      montantMin: montantMin ?? this.montantMin,
      montantMax: montantMax ?? this.montantMax,
      actif: actif ?? this.actif,
    );
  }
}
