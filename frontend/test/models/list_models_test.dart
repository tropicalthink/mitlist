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

  group('ItemList reminder fields', () {
    Map<String, dynamic> base() => {
          'id': 'list-1',
          'group_id': 'group-1',
          'name': 'Groceries',
          'type': 'shopping',
          'created_at': '2026-09-18T10:00:00Z',
          'updated_at': '2026-09-18T10:00:00Z',
        };

    test('parses remind_at into local time and reports it pending', () {
      final list = ItemList.fromJson({
        ...base(),
        'remind_at': '2026-09-20T08:30:00Z',
      });

      expect(list.remindAt, isNotNull);
      expect(list.remindAt!.toUtc(), DateTime.utc(2026, 9, 20, 8, 30));
      expect(list.reminderSentAt, isNull);
      expect(list.hasPendingReminder, isTrue);
      expect(list.toJson()['remind_at'], '2026-09-20T08:30:00.000Z');
    });

    test('a delivered reminder is no longer pending', () {
      final list = ItemList.fromJson({
        ...base(),
        'remind_at': '2026-09-17T08:30:00Z',
        'reminder_sent_at': '2026-09-17T08:30:05Z',
      });

      expect(list.hasPendingReminder, isFalse);
    });

    test('missing reminder keys stay null and out of toJson', () {
      final list = ItemList.fromJson(base());

      expect(list.remindAt, isNull);
      expect(list.hasPendingReminder, isFalse);
      expect(list.toJson().containsKey('remind_at'), isFalse);
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
