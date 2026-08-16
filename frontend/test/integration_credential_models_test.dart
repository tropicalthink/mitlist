import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/integration_credential_models.dart';

void main() {
  group('IntegrationCredential', () {
    test('parses the flattened API representation', () {
      final created = CreatedIntegrationCredential.fromJson({
        'id': 'credential-1',
        'name': 'Kitchen Home Assistant',
        'token_prefix': 'ml_int_abc',
        'group_ids': ['group-1', 'group-2'],
        'scopes': ['lists:read', 'lists:write'],
        'created_at': '2026-08-16T10:00:00Z',
        'last_used_at': '2026-08-16T11:00:00Z',
        'revoked_at': null,
        'token': 'ml_int_secret',
      });

      expect(created.token, 'ml_int_secret');
      expect(created.credential.id, 'credential-1');
      expect(created.credential.groupIds, ['group-1', 'group-2']);
      expect(created.credential.scopes, ['lists:read', 'lists:write']);
      expect(created.credential.isActive, isTrue);
      expect(created.credential.lastUsedAt, isNotNull);
    });

    test('handles omitted optional metadata and revoked credentials', () {
      final credential = IntegrationCredential.fromJson({
        'id': 'credential-2',
        'name': 'Old connection',
        'created_at': '2026-08-16T10:00:00Z',
        'revoked_at': '2026-08-16T12:00:00Z',
      });

      expect(credential.tokenPrefix, isEmpty);
      expect(credential.groupIds, isEmpty);
      expect(credential.scopes, isEmpty);
      expect(credential.lastUsedAt, isNull);
      expect(credential.isActive, isFalse);
    });
  });
}
