import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mitlist/services/product_events.dart';

void main() {
  late List<Map<String, Object?>> sent;
  late bool failNext;

  ProductEvents events({bool enabled = true}) => ProductEvents(
        enabled: enabled,
        send: (body) async {
          if (failNext) {
            failNext = false;
            throw Exception('offline');
          }
          sent.add(body);
        },
      );

  List<String> names(Map<String, Object?> body) => [
        for (final e in body['events']! as List)
          (e as Map<String, Object?>)['name']! as String,
      ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    failNext = false;
  });

  test('events tracked together go out as one batch with an install id',
      () async {
    final client = events();
    client.track(ProductEventName.welcomeShown);
    client.track(ProductEventName.tourSkipped, props: {'page': '2'});
    await pumpEventQueue();

    expect(sent, hasLength(1));
    expect(names(sent.single), ['welcome_shown', 'tour_skipped']);
    expect(sent.single['install_id'], isA<String>());
    final skipped = (sent.single['events']! as List)[1] as Map;
    expect(skipped['props'], {'page': '2'});
  });

  test('the install id stays the same across clients', () async {
    final first = events()..track(ProductEventName.welcomeShown);
    await pumpEventQueue();
    events().track(ProductEventName.tourStarted);
    await pumpEventQueue();

    expect(first, isNotNull);
    expect(sent, hasLength(2));
    expect(sent[0]['install_id'], sent[1]['install_id']);
  });

  test('a failed send keeps the events for the next one', () async {
    final client = events();
    failNext = true;
    client.track(ProductEventName.welcomeShown);
    await pumpEventQueue();
    expect(sent, isEmpty);

    client.track(ProductEventName.tourStarted);
    await pumpEventQueue();
    expect(sent, hasLength(1));
    expect(names(sent.single), ['welcome_shown', 'tour_started']);
  });

  test('disabled (debug and tests) sends nothing and touches nothing',
      () async {
    final client = events(enabled: false);
    client.track(ProductEventName.welcomeShown);
    client.householdStarted(ProductEventName.householdCreated, 'g1');
    await client.noteItemAdded('g1', 'chore');
    await pumpEventQueue();

    expect(sent, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });

  test('first_item_added fires once, only for a household started here',
      () async {
    final client = events();
    client.householdStarted(ProductEventName.householdCreated, 'g1',
        source: 'onboarding');
    await pumpEventQueue();
    await client.noteItemAdded('g1', 'list_item');
    await client.noteItemAdded('g1', 'chore');
    await client.noteItemAdded('older-household', 'expense');
    await pumpEventQueue();

    final all = [for (final body in sent) ...names(body)];
    expect(all, ['household_created', 'first_item_added']);
    final first = (sent.last['events']! as List).single as Map;
    expect(first['group_id'], 'g1');
    expect(first['props'], {'kind': 'list_item'});
  });
}
