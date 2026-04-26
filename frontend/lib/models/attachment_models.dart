class Attachment {
  final String id;
  final String groupId;
  final String userId;
  final String purpose;
  final String objectKey;
  final String contentType;
  final int byteSize;
  final String status;
  final DateTime createdAt;

  const Attachment({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.purpose,
    required this.objectKey,
    required this.contentType,
    required this.byteSize,
    required this.status,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        userId: json['user_id'] as String,
        purpose: json['purpose'] as String,
        objectKey: json['object_key'] as String,
        contentType: (json['content_type'] as String?) ?? 'application/octet-stream',
        byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
        status: (json['status'] as String?) ?? 'pending',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class UploadIntent {
  final Attachment attachment;
  final String objectKey;
  final String uploadUrl;
  final int expiresIn;

  const UploadIntent({
    required this.attachment,
    required this.objectKey,
    required this.uploadUrl,
    required this.expiresIn,
  });

  factory UploadIntent.fromJson(Map<String, dynamic> json) => UploadIntent(
        attachment: Attachment.fromJson((json['attachment'] as Map).cast<String, dynamic>()),
        objectKey: json['object_key'] as String,
        uploadUrl: json['upload_url'] as String,
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      );
}

