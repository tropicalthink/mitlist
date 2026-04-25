class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final dynamic data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'],
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationPreferenceModel {
  final String id;
  final String userId;
  final String type;
  final bool enabled;
  final String channel;

  const NotificationPreferenceModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.enabled,
    required this.channel,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      enabled: json['enabled'] as bool? ?? false,
      channel: json['channel'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'enabled': enabled,
        'channel': channel,
      };
}

