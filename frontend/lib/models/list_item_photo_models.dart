class ListItemPhoto {
  final String attachmentId;
  final String contentType;
  final int byteSize;
  final DateTime createdAt;
  final String url;

  const ListItemPhoto({
    required this.attachmentId,
    required this.contentType,
    required this.byteSize,
    required this.createdAt,
    required this.url,
  });

  factory ListItemPhoto.fromJson(Map<String, dynamic> json) => ListItemPhoto(
        attachmentId: json['attachment_id'] as String,
        contentType: (json['content_type'] as String?) ?? 'application/octet-stream',
        byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        url: json['url'] as String,
      );
}

