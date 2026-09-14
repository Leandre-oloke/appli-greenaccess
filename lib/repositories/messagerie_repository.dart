import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message_model.dart';

/// Messagerie liée à une demande de financement (J5.2, CDC §3 M2) — permet à
/// l'emprunteur, à l'admin et au partenaire financeur assigné d'échanger sur
/// une demande. Sous-collection `demandes_financement/{demandeId}/messages`,
/// en ajout seul (voir firestore.rules) : un fil de discussion lié à un
/// dossier de financement n'est ni modifié ni supprimé une fois un message
/// envoyé.
class MessagerieRepository {
  final FirebaseFirestore _firestore;

  MessagerieRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String demandeId) => _firestore
      .collection('demandes_financement')
      .doc(demandeId)
      .collection('messages');

  /// Flux temps réel des messages d'une demande, du plus ancien au plus
  /// récent (ordre naturel de lecture d'une conversation).
  Stream<List<MessageModel>> streamMessages(String demandeId) {
    return _messagesRef(demandeId).orderBy('created_at').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> envoyerMessage({
    required String demandeId,
    required String auteurId,
    required String auteurNom,
    required String contenu,
  }) async {
    await _messagesRef(demandeId).add({
      'demande_id': demandeId,
      'auteur_id': auteurId,
      'auteur_nom': auteurNom,
      'contenu': contenu,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
