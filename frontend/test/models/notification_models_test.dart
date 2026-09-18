import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/notification_models.dart';

void main() {
  test('the preference patch body carries no server-owned fields', () {
    const pref = NotificationPreferenceModel(
      id: '00000000-0000-0000-0000-000000000000',
      userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      groupId: '11111111-1111-1111-1111-111111111111',
      choreDue: false,
      emailEnabled: true,
    );

    final body = pref.toPatchJson();

    // The API decodes the body strictly; an unknown key fails the whole
    // request, which is how every toggle used to answer 400.
    expect(body.keys, isNot(contains('id')));
    expect(body.keys, isNot(contains('user_id')));
    expect(body.keys, isNot(contains('created_at')));
    expect(body.keys, isNot(contains('updated_at')));
    expect(body['group_id'], '11111111-1111-1111-1111-111111111111');
    expect(body['chore_due'], isFalse);
    expect(body['email_enabled'], isTrue);
    expect(body['push_enabled'], isTrue);
    expect(
      body.keys.toSet(),
      {
        'group_id',
        'chore_due',
        'chore_due_day_of',
        'list_item_added',
        'expense_created',
        'meal_plan_changed',
        'weekly_digest',
        'pinwall_reminder',
        'push_enabled',
        'email_enabled',
      },
    );
  });
}
