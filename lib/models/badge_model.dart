class BadgeModel {
  final String id;
  final String nom;
  final String description;
  final String imageUrl;
  final String type; // formation, financement, assurance
  final DateTime? dateObtention;
  final String? openbadgeUrl;

  const BadgeModel({
    required this.id,
    required this.nom,
    required this.description,
    required this.imageUrl,
    required this.type,
    this.dateObtention,
    this.openbadgeUrl,
  });

  bool get isObtenu => dateObtention != null;

  factory BadgeModel.fromFirestore(Map<String, dynamic> data, String id) {
    return BadgeModel(
      id: id,
      nom: data['nom'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['image_url'] ?? '',
      type: data['type'] ?? 'formation',
      dateObtention: data['date_obtention'] != null
          ? (data['date_obtention'] as dynamic).toDate()
          : null,
      openbadgeUrl: data['openbadge_url'],
    );
  }
}
