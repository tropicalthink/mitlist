import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/calendar_models.dart';

void main() {
  const groupId = '11111111-1111-1111-1111-111111111111';

  Map<String, dynamic> event(String type, [Map<String, dynamic>? extra]) => {
        'id': 'e1',
        'type': type,
        'title': 'Groceries',
        'date': '2026-09-18T17:00:00Z',
        'group_id': groupId,
        ...?extra,
      };

  test('parses a list reminder with its list payload', () {
    final e = CalendarEvent.fromJson(event('list_reminder', {
      'list_reminder': {
        'list_id': '22222222-2222-2222-2222-222222222222',
        'list_name': 'Groceries',
        'list_type': 'shopping',
        'sent': false,
      },
    }));

    expect(e.type, CalendarEventType.listReminder);
    expect(e.listReminder, isNotNull);
    expect(e.listReminder!.listId, '22222222-2222-2222-2222-222222222222');
    expect(e.listReminder!.listName, 'Groceries');
    expect(e.listReminder!.listType, 'shopping');
    expect(e.listReminder!.sent, isFalse);
  });

  test('maps every snake_case server type onto the enum', () {
    expect(CalendarEvent.fromJson(event('meal_plan')).type,
        CalendarEventType.mealPlan);
    expect(CalendarEvent.fromJson(event('chore')).type,
        CalendarEventType.chore);
    expect(CalendarEvent.fromJson(event('recurring_expense')).type,
        CalendarEventType.recurringExpense);
    expect(CalendarEvent.fromJson(event('expense')).type,
        CalendarEventType.expense);
    expect(CalendarEvent.fromJson(event('pinwall_reminder')).type,
        CalendarEventType.pinwallReminder);
  });

  test('unknown types fall back to meal plan instead of throwing', () {
    expect(CalendarEvent.fromJson(event('something_new')).type,
        CalendarEventType.mealPlan);
  });
}
