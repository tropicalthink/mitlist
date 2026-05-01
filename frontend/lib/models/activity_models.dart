class ActivityLogModel {
  final String id;
  final String groupId;
  final String? userId;
  final String action;
  final String entityType;
  final String entityId;
  final dynamic metadata;
  final DateTime createdAt;

  const ActivityLogModel({
    required this.id,
    required this.groupId,
    this.userId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.metadata,
    required this.createdAt,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) => ActivityLogModel(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        userId: json['user_id'] as String?,
        action: json['action'] as String? ?? json['type'] as String? ?? 'unknown',
        entityType: json['entity_type'] as String? ?? 'event',
        entityId: json['entity_id'] as String? ?? json['id'] as String,
        metadata: json['metadata'],
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
