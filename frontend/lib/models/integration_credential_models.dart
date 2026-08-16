class IntegrationCredential {
  const IntegrationCredential({
    required this.id,
    required this.name,
    required this.tokenPrefix,
    required this.groupIds,
    required this.scopes,
    required this.createdAt,
    this.lastUsedAt,
    this.revokedAt,
  });

  final String id;
  final String name;
  final String tokenPrefix;
  final List<String> groupIds;
  final List<String> scopes;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  factory IntegrationCredential.fromJson(Map<String, dynamic> json) {
    return IntegrationCredential(
      id: json['id'] as String,
      name: json['name'] as String,
      tokenPrefix: json['token_prefix'] as String? ?? '',
      groupIds: (json['group_ids'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      scopes: (json['scopes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastUsedAt: _optionalDate(json['last_used_at']),
      revokedAt: _optionalDate(json['revoked_at']),
    );
  }
}

class CreatedIntegrationCredential {
  const CreatedIntegrationCredential({
    required this.credential,
    required this.token,
  });

  final IntegrationCredential credential;
  final String token;

  factory CreatedIntegrationCredential.fromJson(Map<String, dynamic> json) {
    return CreatedIntegrationCredential(
      credential: IntegrationCredential.fromJson(json),
      token: json['token'] as String,
    );
  }
}

DateTime? _optionalDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
