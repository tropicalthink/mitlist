class PinwallPost {
  final String id;
  final String groupId;
  final String userId;
  final String content;
  final DateTime createdAt;

  const PinwallPost({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory PinwallPost.fromJson(Map<String, dynamic> json) => PinwallPost(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'user_id': userId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };
}

