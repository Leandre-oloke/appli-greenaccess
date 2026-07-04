import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _db;
  NotificationRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Stream en temps réel — notifications globales (broadcast), triées par date.
  Stream<List<NotificationModel>> stream() {
    return _db
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// Stream en temps réel — notifications personnelles d'un utilisateur.
  Stream<List<NotificationModel>> streamUserNotifs(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// Envoi d'une notification globale (admin uniquement).
  Future<void> send({
    required String titre,
    required String message,
    String type = 'info',
  }) async {
    await _db.collection('notifications').add({
      'titre': titre,
      'message': message,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    await _db.collection('notifications').doc(id).delete();
  }
}
