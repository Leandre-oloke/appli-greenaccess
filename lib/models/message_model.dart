/// Message d'un fil de discussion lié à une demande de financement (J5.1,
/// CDC §3 M2) — sous-collection `demandes_financement/{demandeId}/messages`.
class MessageModel {
  final String id;
  final String demandeId;
  final String auteurId;
  final String auteurNom;
  final String contenu;
  final DateTime? createdAt;

  const MessageModel({
    required this.id,
    required this.demandeId,
    required this.auteurId,
    required this.auteurNom,
    required this.contenu,
    this.createdAt,
  });

  factory MessageModel.fromFirestore(Map<String, dynamic> data, String id) {
    return MessageModel(
      id: id,
      demandeId: data['demande_id'] ?? '',
      auteurId: data['auteur_id'] ?? '',
      auteurNom: data['auteur_nom'] ?? '',
      contenu: data['contenu'] ?? '',
      createdAt: data['created_at'] != null ? (data['created_at'] as dynamic).toDate() : null,
    );
  }
}
