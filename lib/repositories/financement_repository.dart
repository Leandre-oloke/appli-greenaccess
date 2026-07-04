import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/demande_financement_model.dart';

class FinancementRepository {
  final FirebaseFirestore _firestore;

  FinancementRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<DemandeFinancementModel> submit(DemandeFinancementModel demande) async {
    final doc = await _firestore
        .collection('demandes_financement')
        .add(demande.toFirestore());
    return DemandeFinancementModel.fromFirestore(demande.toFirestore(), doc.id);
  }

  Future<void> updateStatut(String demandeId, StatutDemande statut, {String? commentaire}) async {
    await _firestore.collection('demandes_financement').doc(demandeId).update({
      'statut': statut.name,
      if (commentaire != null) 'commentaire_rejet': commentaire,
    });
  }

  Future<DemandeFinancementModel?> fetchStatut(String demandeId) async {
    final doc = await _firestore.collection('demandes_financement').doc(demandeId).get();
    if (!doc.exists) return null;
    return DemandeFinancementModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<List<DemandeFinancementModel>> fetchUserDemandes(String userId) async {
    final snapshot = await _firestore
        .collection('demandes_financement')
        .where('userId', isEqualTo: userId)
        .orderBy('date_soumission', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => DemandeFinancementModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Stream<DemandeFinancementModel> watchStatut(String demandeId) {
    return _firestore
        .collection('demandes_financement')
        .doc(demandeId)
        .snapshots()
        .map((doc) => DemandeFinancementModel.fromFirestore(doc.data()!, doc.id));
  }
}
