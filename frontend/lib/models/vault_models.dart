class VaultItem {
  final String id;
  final String groupId;
  final String type;
  final String title;
  final String content;
  final DateTime? reminderDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VaultItem({
    required this.id, required this.groupId, required this.type,
    required this.title, required this.content, this.reminderDate,
    required this.createdAt, required this.updatedAt,
  });

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    type: json['type'] as String? ?? 'note',
    title: json['title'] as String,
    content: json['content'] as String? ?? '',
    reminderDate: json['reminder_date'] != null ? DateTime.parse(json['reminder_date'] as String) : null,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'group_id': groupId, 'type': type, 'title': title,
    'content': content,
    if (reminderDate != null) 'reminder_date': reminderDate!.toIso8601String(),
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };
}

class CreateVaultItemRequest {
  final String groupId;
  final String type;
  final String title;
  final String content;
  final DateTime? reminderDate;
  const CreateVaultItemRequest({
    required this.groupId, required this.type, required this.title,
    this.content = '', this.reminderDate,
  });
  Map<String, dynamic> toJson() => {
    'group_id': groupId, 'type': type, 'title': title,
    'content': content,
    if (reminderDate != null) 'reminder_date': reminderDate!.toIso8601String(),
  };
}

class ShareVaultItemRequest {
  final String sharedWithUserId;
  final String permission;
  const ShareVaultItemRequest({required this.sharedWithUserId, required this.permission});
  Map<String, dynamic> toJson() => {'shared_with_user_id': sharedWithUserId, 'permission': permission};
}
