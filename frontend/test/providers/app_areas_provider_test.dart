import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/app_areas_provider.dart';
import 'package:mitlist/providers/chore_provider.dart';
import 'package:mitlist/providers/finance_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _groupId = '11111111-1111-1111-1111-111111111111';
const _me = 'me-1';

Group _household() => Group(
      id: _groupId,
      name: 'Flat 4B',
      isPersonal: false,
      memberCount: 2,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

CurrentChore _chore({required bool mine, String status = 'pending'}) =>
    CurrentChore(
      chore: Chore(
        id: '44444444-4444-4444-4444-444444444444',
        groupId: _groupId,
        name: 'Bins',
        rotationType: 'round-robin',
        frequency: 'weekly',
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
      dueStatus: 'due',
      assignedToMe: mine,
      pendingAssignment: ChoreAssignment(
        id: 'a-1',
        choreId: '44444444-4444-4444-4444-444444444444',
        userId: mine ? _me : 'someone-else',
        status: status,
        dueDate: DateTime.utc(2026, 1, 9),
        assignedAt: DateTime.utc(2026, 1, 2),
        completedAt: null,
      ),
    );

FinanceSummary _balance(int myTotal) => FinanceSummary(
      balances: [
        BalanceEntry(
          userId: _me,
          displayName: 'Me',
          paid: 0,
          owed: -myTotal,
          total: myTotal,
        ),
      ],
      reimbursements: const [],
    );

Future<ProviderContainer> _container({
  Map<String, Object> prefs = const {},
  List<CurrentChore> chores = const [],
  FinanceSummary? summary,
}) async {
  SharedPreferences.setMockInitialValues({
    'user_data': '{"id":"$_me"}',
    ...prefs,
  });
  final container = ProviderContainer(
    overrides: [
      cachedGroupsProvider.overrideWith((ref) async => [_household()]),
      cachedCurrentChoresByGroupProvider
          .overrideWith((ref, id) => Stream.value(chores)),
      cachedFinanceSummaryByGroupProvider
          .overrideWith((ref, id) => Stream.value(summary)),
    ],
  );
  addTearDown(container.dispose);
  // Let the saved choice, the household and its caches load.
  container.read(appAreasProvider);
  await container.read(cachedGroupsProvider.future);
  container.listen(visibleAreasProvider, (_, __) {});
  container.listen(cachedCurrentChoresByGroupProvider(_groupId), (_, __) {});
  container.listen(cachedFinanceSummaryByGroupProvider(_groupId), (_, __) {});
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return container;
}

void main() {
  test('someone who never chose sees every area', () async {
    final c = await _container();
    expect(c.read(appAreasProvider).hasChoice, isFalse);
    expect(c.read(visibleAreasProvider), AppArea.values.toSet());
  });

  test('a saved choice is read under the signed-in user', () async {
    final c = await _container(prefs: {
      'app_areas:$_me': ['lists'],
      // Another account on the same phone chose differently.
      'app_areas:someone-else': ['money'],
    });
    expect(c.read(visibleAreasProvider), {AppArea.lists});
  });

  test('a chore whose turn is mine brings Chores back', () async {
    final c = await _container(
      prefs: {
        'app_areas:$_me': ['lists'],
      },
      chores: [_chore(mine: true)],
    );
    expect(c.read(visibleAreasProvider), {AppArea.lists, AppArea.chores});
  });

  test("someone else's chore, or a done one, does not", () async {
    final c = await _container(
      prefs: {
        'app_areas:$_me': ['lists'],
      },
      chores: [_chore(mine: false), _chore(mine: true, status: 'completed')],
    );
    expect(c.read(visibleAreasProvider), {AppArea.lists});
  });

  test('money I owe or am owed brings Money back', () async {
    final owing = await _container(
      prefs: {
        'app_areas:$_me': ['lists'],
      },
      summary: _balance(-1250),
    );
    expect(owing.read(visibleAreasProvider), {AppArea.lists, AppArea.money});

    final square = await _container(
      prefs: {
        'app_areas:$_me': ['lists'],
      },
      summary: _balance(0),
    );
    expect(square.read(visibleAreasProvider), {AppArea.lists});
  });

  test('choosing saves under the user; clearing shows everything', () async {
    final c = await _container();
    final notifier = c.read(appAreasProvider.notifier);

    await notifier.choose({AppArea.money, AppArea.lists});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('app_areas:$_me'), ['money', 'lists']);
    expect(c.read(appAreasProvider).chosen, {AppArea.money, AppArea.lists});

    await notifier.setShown(AppArea.money, false);
    expect(prefs.getStringList('app_areas:$_me'), ['lists']);

    await notifier.choose(null);
    expect(prefs.getStringList('app_areas:$_me'), isNull);
    expect(c.read(visibleAreasProvider), AppArea.values.toSet());
  });

  test('turning one area off from "everything" keeps the others', () async {
    final c = await _container();
    await c.read(appAreasProvider.notifier).setShown(AppArea.kitchen, false);
    expect(
      c.read(appAreasProvider).chosen,
      {AppArea.chores, AppArea.money, AppArea.lists},
    );
  });
}
