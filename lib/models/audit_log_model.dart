class AuditLogModel {
  final String id;
  final String userId;
  final String action;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  const AuditLogModel({
    required this.id,
    required this.userId,
    required this.action,
    this.details = const {},
    this.createdAt,
  });

  factory AuditLogModel.fromFirestore(Map<String, dynamic> data, String id) {
    return AuditLogModel(
      id: id,
      userId: data['userId'] ?? '',
      action: data['action'] ?? '',
      details: Map<String, dynamic>.from(data['details'] ?? {}),
      createdAt: data['createdAt'] != null ? (data['createdAt'] as dynamic).toDate() : null,
    );
  }
}
