import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/utils/uuid_validation.dart';

void main() {
  group('isApiUuid', () {
    test('accepts RFC-4122 ids', () {
      expect(
        isApiUuid('44e5f732-9e15-4021-a132-e0e460db09ad'),
        isTrue,
      );
    });

    test('rejects bundled grocery slugs', () {
      expect(isApiUuid('milk'), isFalse);
      expect(isApiUuid('strawberry'), isFalse);
    });
  });

  group('CreateListItemRequest.toJson', () {
    test('omits slug canonical_item_id from API payload', () {
      final json = const CreateListItemRequest(
        name: 'Milk',
        canonicalItemId: 'milk',
      ).toJson();

      expect(json['name'], 'Milk');
      expect(json.containsKey('canonical_item_id'), isFalse);
    });

    test('keeps UUID canonical_item_id', () {
      const id = '44e5f732-9e15-4021-a132-e0e460db09ad';
      final json = const CreateListItemRequest(
        name: 'Milk',
        canonicalItemId: id,
      ).toJson();

      expect(json['canonical_item_id'], id);
    });
  });
}
