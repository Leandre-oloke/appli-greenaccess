import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { info, success, warning, alert }

class NotificationModel {
  final String id;
  final String titre;
  final String message;
  final NotificationType type;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.titre,
    required this.message,
    required this.type,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(Map<String, dynamic> data, String id) {
    return NotificationModel(
      id: id,
      titre: data['titre'] ?? '',
      message: data['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (t) => t.name == (data['type'] ?? 'info'),
        orElse: () => NotificationType.info,
      ),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
