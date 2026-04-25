class ChatSessionModel {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSessionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) => ChatSessionModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class ChatMessageModel {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class CreateSessionRequest {
  final String title;
  const CreateSessionRequest({required this.title});
  Map<String, dynamic> toJson() => {'title': title};
}

class UpdateSessionRequest {
  final String title;
  const UpdateSessionRequest({required this.title});
  Map<String, dynamic> toJson() => {'title': title};
}

class SendMessageRequest {
  final String content;
  const SendMessageRequest({required this.content});
  Map<String, dynamic> toJson() => {'content': content};
}

