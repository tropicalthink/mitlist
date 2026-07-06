class PinwallPost {
  final String id;
  final String groupId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime? remindAt;
  final DateTime? reminderSentAt;
  final String? linkedEntityType;
  final String? linkedEntityId;

  const PinwallPost({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.remindAt,
    this.reminderSentAt,
    this.linkedEntityType,
    this.linkedEntityId,
  });

  factory PinwallPost.fromJson(Map<String, dynamic> json) => PinwallPost(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        remindAt: json['remind_at'] != null
            ? DateTime.parse(json['remind_at'] as String)
            : null,
        reminderSentAt: json['reminder_sent_at'] != null
            ? DateTime.parse(json['reminder_sent_at'] as String)
            : null,
        linkedEntityType: json['linked_entity_type'] as String?,
        linkedEntityId: json['linked_entity_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'user_id': userId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        'remind_at': remindAt?.toIso8601String(),
        'reminder_sent_at': reminderSentAt?.toIso8601String(),
        if (linkedEntityType != null) 'linked_entity_type': linkedEntityType,
        if (linkedEntityId != null) 'linked_entity_id': linkedEntityId,
      };
}
