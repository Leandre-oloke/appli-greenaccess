import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/paiement_model.dart';

class PaiementRepository {
  final FirebaseFirestore _firestore;

  PaiementRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Génère une référence de paiement unique lisible par l'opérateur.
  String _genReference() {
    final rand = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
    final code = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'GA-$code';
  }

  /// Crée un paiement en attente et renvoie la référence générée.
  Future<PaiementModel> initierPaiement({
    required String demandeId,
    required String echeanceId,
    required String userId,
    required double montant,
    required OperateurMobileMoney operateur,
  }) async {
    final reference = _genReference();
    final now = DateTime.now();
    final payload = {
      'demandeId': demandeId,
      'echeanceId': echeanceId,
      'userId': userId,
      'montant': montant,
      'operateur': operateur.name,
      'statut': StatutPaiement.enAttente.name,
      'reference': reference,
      'date_creation': Timestamp.fromDate(now),
      'date_confirmation': null,
    };
    final doc = await _firestore.collection('paiements').add(payload);
    return PaiementModel(
      id: doc.id,
      demandeId: demandeId,
      echeanceId: echeanceId,
      userId: userId,
      montant: montant,
      operateur: operateur,
      statut: StatutPaiement.enAttente,
      reference: reference,
      dateCreation: now,
    );
  }

  /// Marque le paiement comme confirmé et met à jour l'échéance.
  Future<void> confirmerPaiement({
    required String paiementId,
    required String demandeId,
    required String echeanceId,
  }) async {
    final batch = _firestore.batch();

    // Mise à jour du paiement
    batch.update(_firestore.collection('paiements').doc(paiementId), {
      'statut': StatutPaiement.confirme.name,
      'date_confirmation': FieldValue.serverTimestamp(),
    });

    // Marque l'échéance comme payée
    batch.update(
      _firestore
          .collection('demandes_financement')
          .doc(demandeId)
          .collection('remboursements')
          .doc(echeanceId),
      {
        'paye': true,
        'date_paiement': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  Future<List<PaiementModel>> fetchPaiements(String userId) async {
    final snap = await _firestore
        .collection('paiements')
        .where('userId', isEqualTo: userId)
        .orderBy('date_creation', descending: true)
        .get();
    return snap.docs
        .map((d) => PaiementModel.fromFirestore(d.data(), d.id))
        .toList();
  }
}
