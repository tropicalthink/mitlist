class PushSubscriptionModel {
  final String id;
  final String userId;
  final String endpoint;
  final String p256dh;
  final String auth;
  final DateTime createdAt;

  const PushSubscriptionModel({
    required this.id,
    required this.userId,
    required this.endpoint,
    required this.p256dh,
    required this.auth,
    required this.createdAt,
  });

  factory PushSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return PushSubscriptionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      endpoint: json['endpoint'] as String,
      p256dh: json['p256dh'] as String,
      auth: json['auth'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

