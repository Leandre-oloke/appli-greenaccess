import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/demande_financement_model.dart';
import '../models/remboursement_model.dart';
import 'audit_repository.dart';

class FinancementRepository {
  final FirebaseFirestore _firestore;
  final AuditRepository _audit;

  FinancementRepository({FirebaseFirestore? firestore, AuditRepository? audit})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditRepository(firestore: firestore);

  Future<DemandeFinancementModel> submit(DemandeFinancementModel demande) async {
    final doc = await _firestore
        .collection('demandes_financement')
        .add(demande.toFirestore());
    await _audit.logAction(
      userId: demande.userId,
      action: 'financement_soumis',
      details: {'demandeId': doc.id, 'montant': demande.montant},
    );
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

  /// Récupère les échéances de remboursement d'une demande.
  Future<List<RemboursementModel>> fetchRemboursements(String demandeId) async {
    final snap = await _firestore
        .collection('demandes_financement')
        .doc(demandeId)
        .collection('remboursements')
        .orderBy('numero_echeance')
        .get();
    return snap.docs
        .map((d) => RemboursementModel.fromFirestore(d.data(), d.id))
        .toList();
  }

  /// Génère automatiquement un échéancier mensuel sur [dureesMois] mois.
  Future<void> genererEcheancier({
    required String demandeId,
    required double montantTotal,
    required int dureesMois,
    required DateTime dateDebut,
  }) async {
    final mensualite = montantTotal / dureesMois;
    final col = _firestore
        .collection('demandes_financement')
        .doc(demandeId)
        .collection('remboursements');

    final batch = _firestore.batch();
    for (int i = 1; i <= dureesMois; i++) {
      final doc = col.doc();
      batch.set(doc, {
        'demandeId': demandeId,
        'numero_echeance': i,
        'date_echeance': DateTime(dateDebut.year, dateDebut.month + i, dateDebut.day),
        'montant': mensualite,
        'paye': false,
        'date_paiement': null,
      });
    }
    await batch.commit();
  }
}
