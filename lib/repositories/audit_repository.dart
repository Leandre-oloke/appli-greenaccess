import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/audit_log_model.dart';

/// Journal d'audit inviolable (J3.7-J3.8, CDC §6) : trace les actions
/// critiques (soumission de demande, souscription d'assurance, paiement,
/// suppression de compte) avec horodatage et identité de l'auteur. La
/// collection `audit_logs` est en ajout seul — `firestore.rules` interdit
/// toute modification ou suppression, même par un admin, une fois un
/// document créé.
class AuditRepository {
  final FirebaseFirestore _firestore;

  AuditRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// N'expose jamais d'exception à l'appelant : le journal d'audit ne doit
  /// jamais faire échouer l'action métier qu'il trace (ex. un problème réseau
  /// pendant l'écriture du log ne doit pas empêcher une souscription valide).
  Future<void> logAction({
    required String userId,
    required String action,
    Map<String, dynamic> details = const {},
  }) async {
    try {
      await _firestore.collection('audit_logs').add({
        'userId': userId,
        'action': action,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non bloquant — voir le commentaire de classe.
    }
  }

  /// Réservé aux admins côté règles Firestore — consultation du journal,
  /// pas encore exposée dans une UI admin (hors périmètre J3.7-J3.8).
  Future<List<AuditLogModel>> fetchLogs({int limit = 100}) async {
    final snapshot = await _firestore
        .collection('audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => AuditLogModel.fromFirestore(d.data(), d.id)).toList();
  }
}
