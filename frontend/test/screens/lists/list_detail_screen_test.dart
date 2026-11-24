import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/screens/lists/list_detail_screen.dart';
import 'package:mitlist/services/list_service.dart';
import 'package:mitlist/services/restock_service.dart';
import 'package:mitlist/services/scan/bundled_grocery_suggestion_service.dart';
import 'package:mitlist/services/scan/canonical_link_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/services/sync_scheduler.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/animated_check_toggle.dart';
import 'package:mitlist/widgets/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';

const _gid = '11111111-1111-1111-1111-111111111111';
const _lid = '22222222-2222-2222-2222-222222222222';

class _Service implements ListService {
  @override
  Future<void> flushListNotifications(String listId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Serves a fixed list from the cache and records the edits made to it.
/// Anything else the screen asks of the repository answers "nothing".
class _Repo implements ListRepository {
  _Repo(this.items);

  final List<ListItem> items;
  final List<UpdateListItemRequest> updates = [];

  @override
  Stream<List<ListItem>> watchItemsByList(String listId) => Stream.value(items);

  @override
  Future<List<ListItem>> getItemsByListOnce(String listId) async => items;

  @override
  Future<String?> getGroupId(String listId) async => _gid;

  @override
  Future<String?> getListType(String listId) async => 'shopping';

  @override
  Future<void> refreshListDetail(String listId) async {}

  @override
  String resolveListId(String id) => id;

  @override
  Stream<({String from, String to})> get listIdChanges => const Stream.empty();

  @override
  void triggerAutoSync() {}

  @override
  Future<ListItem> updateItemOfflineFirst(
    String listId,
    String itemId,
    UpdateListItemRequest req,
  ) async {
    updates.add(req);
    return items.firstWhere((i) => i.id == itemId);
  }

  final List<String> deleted = [];
  final List<String> created = [];

  @override
  Future<void> deleteItemOfflineFirst(String listId, String itemId) async {
    deleted.add(itemId);
  }

  @override
  Future<ListItem> createItemOfflineFirst(
    String listId,
    CreateListItemRequest req, {
    bool deferImmediateSync = false,
    String? addedBy,
  }) async {
    created.add(req.name);
    return _item('new-${created.length}', req.name, items.length);
  }

  @override
  Future<ListItem> addItemAmountOfflineFirst(
    String listId, {
    required String name,
    required double amount,
    String unit = '',
    String note = '',
    String? canonicalItemId,
    bool deferImmediateSync = false,
    String? addedBy,
  }) async {
    created.add(name);
    return _item('new-${created.length}', name, items.length, quantity: amount);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value(null);
}

ListItem _item(
  String id,
  String name,
  int position, {
  double quantity = 1,
  String unit = '',
  String note = '',
  int? priceCents,
}) =>
    ListItem(
      id: id,
      listId: _lid,
      name: name,
      quantity: quantity,
      unit: unit,
      note: note,
      checked: false,
      position: position,
      priceCents: priceCents,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

class _Bundled extends BundledGrocerySuggestionService {
  @override
  Future<List<GrocerySuggestion>> suggest(String query, {int limit = 8}) async {
    if (query.trim().isEmpty) return const [];
    return const [
      GrocerySuggestion(
          canonicalItemId: 'milk', name: 'Milk', category: 'Dairy', unit: 'l'),
      GrocerySuggestion(
          canonicalItemId: 'mint', name: 'Mint', category: 'Produce', unit: ''),
    ];
  }
}

Future<_Repo> _open(
  WidgetTester tester,
  List<ListItem> items, {
  List<RestockSuggestion> runningLow = const [],
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true),
  );
  addTearDown(db.close);
  final repo = _Repo(items);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      grocerySeedProvider.overrideWith((ref) async {}),
      listServiceProviderAsync.overrideWith((ref) async => _Service()),
      listRepositoryProvider.overrideWith((ref) async => repo),
      cachedGroupsProvider.overrideWith((ref) async => const []),
      runningLowProvider.overrideWith((ref, id) async => runningLow),
      bundledGrocerySuggestionServiceProvider.overrideWithValue(_Bundled()),
    ],
    child: MaterialApp(
      theme: MitlistTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ListDetailScreen(listId: _lid, initialListName: 'Groceries'),
    ),
  ));
  await _settle(tester);
  // The fake repository has no server to refresh from; its "couldn't load"
  // note would sit over the edit controls at the bottom of the screen.
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .removeCurrentSnackBar(reason: SnackBarClosedReason.remove);
  await _settle(tester);
  return repo;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Taps an item's words to edit them in place.
Future<void> _startEditing(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await _settle(tester);
}

/// Somewhere on the screen that is neither the line nor its controls.
Future<void> _tapOutside(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 560));
  await _settle(tester);
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  testWidgets('tapping the words edits them in place; return saves',
      (tester) async {
    final repo = await _open(tester, [
      _item('a', 'Milk', 0),
      _item('b', 'Bananas', 1),
    ]);

    await tester.tap(find.text('Bananas'));
    await _settle(tester);
    final field = find.byKey(const ValueKey('item-line-edit-b'));
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Plantains');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(repo.updates.single.name, 'Plantains');
    expect(field, findsNothing);
    // Return moves on to the add line, like the next line of a checklist.
    final addLine = tester.widget<TextField>(
      find.byKey(const ValueKey('list-add-line')),
    );
    expect(addLine.focusNode!.hasFocus, isTrue);
  });

  testWidgets('emptying a line removes the item', (tester) async {
    final repo = await _open(tester, [
      _item('a', 'Milk', 0),
      _item('b', 'Bananas', 1),
    ]);

    await tester.tap(find.text('Bananas'));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('item-line-edit-b')), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(repo.deleted, ['b']);
    expect(repo.updates, isEmpty);
  });

  testWidgets('the add line adds on return and stays open for the next',
      (tester) async {
    final repo = await _open(tester, [_item('a', 'Milk', 0)]);

    final addLine = find.byKey(const ValueKey('list-add-line'));
    await tester.tap(addLine);
    await tester.enterText(addLine, 'Eggs');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(repo.created, ['Eggs']);
    final field = tester.widget<TextField>(addLine);
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('tapping the name edits it and does not tick it', (tester) async {
    final repo = await _open(tester, [_item('a', 'Milk', 0)]);

    await _startEditing(tester, 'Milk');

    expect(_key('item-line-edit-a'), findsOneWidget);
    expect(_key('list-edit-accessory'), findsOneWidget);
    expect(repo.updates, isEmpty);
    // The "tune" button and its sheet are gone: the details are right here.
    expect(_key('item-line-details-a'), findsNothing);
  });

  testWidgets('the checkbox ticks and does not start an edit', (tester) async {
    final repo = await _open(tester, [_item('a', 'Milk', 0)]);

    await tester.tap(find.byType(AnimatedCheckToggle));
    await _settle(tester);

    expect(repo.updates.single.checked, isTrue);
    expect(_key('item-line-edit-a'), findsNothing);
    expect(_key('list-edit-accessory'), findsNothing);
  });

  testWidgets('the caret lands where the name was tapped', (tester) async {
    await _open(tester, [_item('a', 'Watermelon', 0)]);

    final name = find.text('Watermelon');
    await tester.tapAt(tester.getTopLeft(name) + const Offset(1, 8));
    await _settle(tester);
    final field = tester.widget<TextField>(_key('item-line-edit-a'));
    expect(field.controller!.selection.baseOffset, 0);
    await _tapOutside(tester);

    await tester.tapAt(tester.getCenter(name));
    await _settle(tester);
    final offset = tester
        .widget<TextField>(_key('item-line-edit-a'))
        .controller!
        .selection
        .baseOffset;
    expect(offset, inInclusiveRange(3, 7));
  });

  testWidgets(
      'amount, unit, price and note set in one edit are saved in one write, '
      'and moving between them does not save early', (tester) async {
    final repo = await _open(tester, [
      _item('a', 'Milk', 0),
      _item('b', 'Bananas', 1),
    ]);

    await _startEditing(tester, 'Bananas');

    // Price: the chip opens a numeric field in the row.
    await tester.tap(_key('list-edit-price'));
    await _settle(tester);
    expect(_key('list-edit-price-field'), findsOneWidget);
    await tester.enterText(_key('list-edit-price-field'), '3,5');
    await tester.tap(_key('list-edit-back'));
    await _settle(tester);
    expect(repo.updates, isEmpty);
    expect(find.text('\$3.50'), findsOneWidget);

    // Note: a second field opens under the name, inside the line.
    await tester.ensureVisible(_key('list-edit-note'));
    await tester.tap(_key('list-edit-note'));
    await _settle(tester);
    await tester.enterText(_key('item-line-note-b'), 'ripe ones');
    await _settle(tester);
    expect(repo.updates, isEmpty);

    // Unit: one tap on a common unit.
    await tester.ensureVisible(_key('list-edit-unit'));
    await tester.tap(_key('list-edit-unit'));
    await _settle(tester);
    await tester.tap(_key('list-edit-unit-option-kg'));
    await _settle(tester);

    // Amount: + twice.
    await tester.ensureVisible(_key('list-edit-more'));
    await tester.tap(_key('list-edit-more'));
    await tester.tap(_key('list-edit-more'));
    await _settle(tester);

    expect(repo.updates, isEmpty);
    expect(_key('item-line-edit-b'), findsOneWidget);

    await _tapOutside(tester);

    expect(_key('item-line-edit-b'), findsNothing);
    final update = repo.updates.single;
    expect(update.quantity, 3);
    expect(update.unit, 'kg');
    expect(update.priceCents, 350);
    expect(update.note, 'ripe ones');
    expect(update.name, isNull);
  });

  testWidgets('scrolling the list while editing does not end the edit',
      (tester) async {
    final repo = await _open(tester, [
      for (var i = 0; i < 30; i++) _item('i$i', 'Item $i', i),
    ]);

    await _startEditing(tester, 'Item 1');
    await tester.tap(_key('list-edit-more'));
    await tester.dragFrom(const Offset(200, 500), const Offset(0, -200));
    await _settle(tester);

    // The line may have scrolled off screen; it is kept, still editing.
    expect(
      find.byKey(const ValueKey('item-line-edit-i1'), skipOffstage: false),
      findsOneWidget,
    );
    expect(_key('list-edit-accessory'), findsOneWidget);
    expect(repo.updates, isEmpty);
  });

  testWidgets('return in the note field saves the edit', (tester) async {
    final repo = await _open(tester, [_item('a', 'Milk', 0, note: 'oat')]);

    await _startEditing(tester, 'Milk');
    // An item with a note opens with its note field showing.
    expect(_key('item-line-note-a'), findsOneWidget);
    await tester.enterText(_key('item-line-note-a'), 'oat, not cow');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(repo.updates.single.note, 'oat, not cow');
    expect(repo.updates.single.name, isNull);
  });

  testWidgets('an untouched edit writes nothing; minus stops at one',
      (tester) async {
    final repo = await _open(tester, [_item('a', 'Milk', 0)]);

    await _startEditing(tester, 'Milk');
    final less = tester.widget<IconButton>(
      find.descendant(
        of: _key('list-edit-less'),
        matching: find.byType(IconButton),
      ),
    );
    expect(less.onPressed, isNull);
    await _tapOutside(tester);

    expect(_key('item-line-edit-a'), findsNothing);
    expect(repo.updates, isEmpty);
  });

  testWidgets('clearing the price removes it', (tester) async {
    final repo =
        await _open(tester, [_item('a', 'Coffee', 0, priceCents: 899)]);

    await _startEditing(tester, 'Coffee');
    expect(find.text('\$8.99'), findsOneWidget);
    await tester.tap(_key('list-edit-price'));
    await _settle(tester);
    await tester.tap(_key('list-edit-price-clear'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(repo.updates.single.priceCents, 0);
    expect(_key('item-line-edit-a'), findsNothing);
  });

  testWidgets('an amount typed into the name is read like the add line',
      (tester) async {
    final repo = await _open(tester, [_item('a', 'Flour', 0)]);

    await _startEditing(tester, 'Flour');
    await tester.enterText(_key('item-line-edit-a'), '2 kg flour');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    final update = repo.updates.single;
    expect(update.name, 'flour');
    expect(update.quantity, 2);
    expect(update.unit, 'kg');
  });

  testWidgets('the back button saves the edit', (tester) async {
    final repo = await _open(tester, [_item('a', 'Milk', 0)]);

    await _startEditing(tester, 'Milk');
    await tester.tap(_key('list-edit-more'));
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(repo.updates.single.quantity, 2);
    expect(_key('item-line-edit-a'), findsNothing);
  });

  testWidgets('ticking another item saves the edit first', (tester) async {
    final repo = await _open(tester, [
      _item('a', 'Milk', 0),
      _item('b', 'Bananas', 1),
    ]);

    await _startEditing(tester, 'Bananas');
    await tester.tap(_key('list-edit-more'));
    await tester.tap(find.byType(AnimatedCheckToggle).first);
    await _settle(tester);

    expect(repo.updates.map((u) => u.quantity), contains(2));
    expect(repo.updates.where((u) => u.checked == true), hasLength(1));
    expect(_key('item-line-edit-b'), findsNothing);
  });

  testWidgets(
      'on a 320dp screen at twice the text size the controls scroll, '
      'nothing overflows, and delete is reachable', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = await _open(
      tester,
      [
        _item('a', 'Milk', 0),
        _item('b', 'Bananas', 1, unit: 'kg', note: 'ripe', priceCents: 350),
      ],
      size: const Size(320, 640),
    );

    await _startEditing(tester, 'Bananas');
    expect(tester.takeException(), isNull);
    expect(_key('list-edit-accessory'), findsOneWidget);

    await tester.dragUntilVisible(
      _key('list-edit-delete'),
      _key('list-edit-accessory-scroll'),
      const Offset(-120, 0),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(_key('list-edit-delete'));
    await _settle(tester);

    expect(repo.deleted, ['b']);
    expect(repo.updates, isEmpty);
  });

  testWidgets(
      'typing swaps "you might also need" for matches under the add line',
      (tester) async {
    final repo = await _open(
      tester,
      [_item('a', 'Bananas', 0)],
      runningLow: const [
        RestockSuggestion(
          canonicalItemId: 'coffee',
          name: 'Coffee',
          intervalDays: 14,
          daysSince: 15,
          reason: RestockReason.due,
        ),
      ],
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // At rest: the household's usual buys sit at the end of the list.
    expect(find.text(l10n.scanReviewYouMightNeed), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);

    final addLine = find.byKey(const ValueKey('list-add-line'));
    await tester.tap(addLine);
    await tester.enterText(addLine, 'mi');
    await _settle(tester);

    // Typing: matches appear as lines right under the words…
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Mint'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Milk')).dy,
      greaterThan(tester.getTopLeft(addLine).dy),
    );
    // …and the usual buys step aside.
    expect(find.text('Coffee'), findsNothing);

    await tester.tap(find.text('Mint'));
    await _settle(tester);
    expect(repo.created, ['Mint']);
    expect(find.text('Milk'), findsNothing);
  });

  group('line editing with undo / redo', () {
    testWidgets(
        'amount, unit, price and note set in one edit are one undo step: '
        'undo restores all four, redo reapplies them', (tester) async {
      final (:repo, :db) = await _openReal(tester, [
        _row('a', 'Milk', 0),
        _row('b', 'Bananas', 1),
      ]);

      await _startEditing(tester, 'Bananas');
      await tester.tap(_key('list-edit-price'));
      await _settle(tester);
      await tester.enterText(_key('list-edit-price-field'), '3,5');
      await tester.tap(_key('list-edit-back'));
      await _settle(tester);
      await tester.ensureVisible(_key('list-edit-note'));
      await tester.tap(_key('list-edit-note'));
      await _settle(tester);
      await tester.enterText(_key('item-line-note-b'), 'ripe ones');
      await _settle(tester);
      await tester.ensureVisible(_key('list-edit-unit'));
      await tester.tap(_key('list-edit-unit'));
      await _settle(tester);
      await tester.tap(_key('list-edit-unit-option-kg'));
      await _settle(tester);
      await tester.ensureVisible(_key('list-edit-more'));
      await tester.tap(_key('list-edit-more'));
      await tester.tap(_key('list-edit-more'));
      await _settle(tester);
      await _tapOutside(tester);

      var b = (await _stored(repo, 'b'))!;
      expect((b.quantity, b.unit, b.priceCents), (3, 'kg', 350));
      expect((await _lastPatch(db, 'b'))['note'], 'ripe ones');
      expect(_arrow(tester, 'list-undo').onPressed, isNotNull);
      expect(_arrow(tester, 'list-redo').onPressed, isNull);

      await tester.tap(_key('list-undo'));
      await _settle(tester);
      b = (await _stored(repo, 'b'))!;
      expect((b.quantity, b.unit, b.priceCents ?? 0), (1, '', 0));
      expect((await _lastPatch(db, 'b'))['note'], '');
      // One step: nothing older is left to undo.
      expect(_arrow(tester, 'list-undo').onPressed, isNull);
      expect(_arrow(tester, 'list-redo').onPressed, isNotNull);

      await tester.tap(_key('list-redo'));
      await _settle(tester);
      b = (await _stored(repo, 'b'))!;
      expect((b.quantity, b.unit, b.priceCents), (3, 'kg', 350));
      expect((await _lastPatch(db, 'b'))['note'], 'ripe ones');
      expect(_arrow(tester, 'list-undo').onPressed, isNotNull);
      expect(_arrow(tester, 'list-redo').onPressed, isNull);
    });

    testWidgets(
        'undo while a line is edited (keyboard up) commits it and undoes '
        'that edit, then the change before it; the keyboard goes',
        (tester) async {
      final (:repo, :db) = await _openReal(tester, [
        _row('a', 'Milk', 0),
        _row('b', 'Bananas', 1),
      ]);
      await tester.tap(find.byType(AnimatedCheckToggle).first);
      await _settle(tester);
      expect((await _stored(repo, 'a'))!.checked, isTrue);

      // The add line had the keyboard before the edit took it.
      await tester.tap(find.byKey(const ValueKey('list-add-line')));
      await _settle(tester);
      _keyboardUp(tester);
      await _startEditing(tester, 'Bananas');
      await tester.tap(_key('list-edit-more'));
      await _settle(tester);
      expect(_key('list-edit-accessory'), findsOneWidget);

      await tester.tap(_key('list-undo'));
      await _settle(tester);

      expect((await _stored(repo, 'b'))!.quantity, 1);
      expect((await _stored(repo, 'a'))!.checked, isTrue,
          reason: 'the edit is undone, not the tick before it');
      expect(_key('item-line-edit-b'), findsNothing);
      expect(_key('list-edit-accessory'), findsNothing);
      expect(_addLineFocused(tester), isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(_arrow(tester, 'list-undo').onPressed, isNotNull);
      expect(_arrow(tester, 'list-redo').onPressed, isNotNull);

      await tester.tap(_key('list-undo'));
      await _settle(tester);
      expect((await _stored(repo, 'a'))!.checked, isFalse);

      // Redo walks forward in order: the tick, then the edit.
      await tester.tap(_key('list-redo'));
      await _settle(tester);
      await tester.tap(_key('list-redo'));
      await _settle(tester);
      expect((await _stored(repo, 'a'))!.checked, isTrue);
      expect((await _stored(repo, 'b'))!.quantity, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('delete from the edit controls, then undo, puts the row back',
        (tester) async {
      final (:repo, :db) = await _openReal(tester, [
        _row('a', 'Milk', 0),
        _row('b', 'Bananas', 1),
        _row('c', 'Coffee', 2),
      ]);

      await _startEditing(tester, 'Bananas');
      await tester.dragUntilVisible(
        _key('list-edit-delete'),
        _key('list-edit-accessory-scroll'),
        const Offset(-120, 0),
      );
      await tester.tap(_key('list-edit-delete'));
      await _settle(tester);
      expect(await _stored(repo, 'b'), isNull);
      expect(find.text('Bananas'), findsNothing);
      expect(_key('list-edit-accessory'), findsNothing);
      expect(tester.testTextInput.hasAnyClients, isFalse);

      await tester.tap(_key('list-undo'));
      await _settle(tester);
      expect((await _stored(repo, 'b'))!.position, 1);
      final ys = [
        for (final name in ['Milk', 'Bananas', 'Coffee'])
          tester.getTopLeft(find.text(name)).dy,
      ];
      expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue, reason: 'back in place');
      expect(_arrow(tester, 'list-undo').onPressed, isNull);
    });

    testWidgets('emptying a line deletes it, and undo brings it back',
        (tester) async {
      final (:repo, :db) = await _openReal(tester, [
        _row('a', 'Milk', 0),
        _row('b', 'Bananas', 1, quantity: 2, unit: 'kg'),
      ]);

      await _startEditing(tester, 'Bananas');
      await tester.enterText(_key('item-line-edit-b'), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      expect(await _stored(repo, 'b'), isNull);

      await tester.tap(_key('list-undo'));
      await _settle(tester);
      final b = (await _stored(repo, 'b'))!;
      expect((b.name, b.quantity, b.unit), ('Bananas', 2, 'kg'));
      expect(find.text('Bananas'), findsOneWidget);
      expect(_arrow(tester, 'list-undo').onPressed, isNull);
      expect(_arrow(tester, 'list-redo').onPressed, isNotNull);
    });

    testWidgets(
        'the arrows stay reachable and right while the keyboard and the '
        'edit controls are up; an untouched edit is no step', (tester) async {
      final (:repo, :db) = await _openReal(tester, [
        _row('a', 'Milk', 0),
        _row('b', 'Bananas', 1),
      ]);
      await tester.tap(find.byType(AnimatedCheckToggle).first);
      await _settle(tester);
      await tester.tap(_key('list-undo'));
      await _settle(tester);
      expect((await _stored(repo, 'a'))!.checked, isFalse);

      _keyboardUp(tester);
      await _startEditing(tester, 'Bananas');
      expect(_key('list-edit-accessory'), findsOneWidget);
      final undo = tester.getRect(_key('list-undo'));
      final redo = tester.getRect(_key('list-redo'));
      final accessory = tester.getRect(_key('list-edit-accessory'));
      expect(undo.top, greaterThanOrEqualTo(0));
      expect(redo.right, lessThanOrEqualTo(390));
      expect(redo.bottom, lessThan(accessory.top));
      expect(_arrow(tester, 'list-undo').onPressed, isNull);
      expect(_arrow(tester, 'list-redo').onPressed, isNotNull);

      // Nothing was changed in the edit: committing it records nothing, so
      // the redo it would otherwise wipe is still there.
      await tester.tap(_key('list-redo'));
      await _settle(tester);
      expect((await _stored(repo, 'a'))!.checked, isTrue);
      expect(_key('item-line-edit-b'), findsNothing);
      expect(_arrow(tester, 'list-undo').onPressed, isNotNull);
      expect(_arrow(tester, 'list-redo').onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
      'on a 360dp phone amount, unit, price and note fit without scrolling, '
      'and the row shows it scrolls to the rest', (tester) async {
    await _open(
      tester,
      [
        _item('b', 'Bananas', 0, unit: 'kg', note: 'ripe ones', priceCents: 350)
      ],
      size: const Size(360, 780),
    );

    await _startEditing(tester, 'Bananas');
    expect(tester.takeException(), isNull);
    for (final key in [
      'list-edit-less',
      'list-edit-quantity',
      'list-edit-more',
      'list-edit-unit',
      'list-edit-price',
      'list-edit-note',
    ]) {
      final rect = tester.getRect(_key(key));
      expect(rect.left, greaterThanOrEqualTo(0), reason: key);
      expect(rect.right, lessThanOrEqualTo(360), reason: key);
      expect(rect.height, greaterThanOrEqualTo(44), reason: key);
    }
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('\$3.50'), findsOneWidget);
    expect(_key('list-edit-accessory-more'), findsOneWidget);
    expect(_key('list-edit-accessory-more-before'), findsNothing);

    await tester.dragUntilVisible(
      _key('list-edit-delete'),
      _key('list-edit-accessory-scroll'),
      const Offset(-200, 0),
    );
    await tester.drag(
        _key('list-edit-accessory-scroll'), const Offset(-400, 0));
    await _settle(tester);
    expect(_key('list-edit-accessory-more'), findsNothing);
    expect(_key('list-edit-accessory-more-before'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('undo / redo arrows', () {
    testWidgets('appear with the first change and step through it',
        (tester) async {
      final (:repo, :db) = await _openReal(tester, [
        _row('a', 'Milk', 0),
        _row('b', 'Bananas', 1),
      ]);
      expect(find.byKey(const ValueKey('list-undo')), findsNothing,
          reason: 'hidden until the visit changes something');

      await _menu(tester, 'Check all');
      expect(_arrow(tester, 'list-undo').onPressed, isNotNull);
      expect(_arrow(tester, 'list-redo').onPressed, isNull);
      expect(_arrow(tester, 'list-undo').tooltip, 'Undo');
      expect(tester.getSize(find.byKey(const ValueKey('list-undo'))).width,
          greaterThanOrEqualTo(44));
      expect(await _checked(repo), {'a': true, 'b': true});

      await tester.tap(find.byKey(const ValueKey('list-undo')));
      await _settle(tester);
      expect(await _checked(repo), {'a': false, 'b': false});
      expect(_arrow(tester, 'list-undo').onPressed, isNull);
      expect(_arrow(tester, 'list-redo').onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('list-redo')));
      await _settle(tester);
      expect(await _checked(repo), {'a': true, 'b': true});
      expect(find.byKey(const ValueKey('list-undo')), findsOneWidget);
    });

    testWidgets('undoing a clear confirms how many rows came back',
        (tester) async {
      final (:repo, :db) = await _openReal(tester, [
        _row('a', 'Milk', 0),
        _row('b', 'Bananas', 1),
      ]);

      await _menu(tester, 'Clear list');
      await tester.tap(find.widgetWithText(AppButton, 'CLEAR LIST').last);
      await _settle(tester);
      expect(await repo.getItemsByListOnce(_lid), isEmpty);

      await tester.tap(find.byKey(const ValueKey('list-undo')));
      await _settle(tester);
      expect((await repo.getItemsByListOnce(_lid)).map((i) => i.id).toSet(),
          {'a', 'b'});
      expect(find.text('Restored 2 items'), findsOneWidget);
    });

    testWidgets('a change a housemate overrode is not undone, and says so',
        (tester) async {
      final (:repo, :db) = await _openReal(tester, [_row('a', 'Milk', 0)]);

      await _menu(tester, 'Check all');
      // A household member unticks it again before the undo.
      await db.upsertListItemsRows([_row('a', 'Milk', 0)]);
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('list-undo')));
      await _settle(tester);
      expect(find.text("Someone else changed this, so it wasn't undone"),
          findsOneWidget);
      expect(_arrow(tester, 'list-undo').onPressed, isNull);
    });

    testWidgets('fit a 320dp app bar beside a long list name', (tester) async {
      await _openReal(
        tester,
        [_row('a', 'Milk', 0)],
        width: 320,
        listName: 'The very long name of our weekly big shopping list',
      );
      await _menu(tester, 'Check all');

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('list-undo')), findsOneWidget);
      expect(find.byKey(const ValueKey('list-redo')), findsOneWidget);
      final undoBox = tester.getRect(find.byKey(const ValueKey('list-undo')));
      expect(undoBox.right, lessThanOrEqualTo(320));
    });
  });

  group('outbox hold', () {
    testWidgets(
        'the list holds the outbox while it is the location; a sheet over '
        'it keeps the hold, leaving releases it', (tester) async {
      final scheduler = SyncScheduler();
      final router = await _openRouted(tester, scheduler);
      expect(scheduler.isHeld, isFalse, reason: 'not on the list yet');

      router.go('/lists/$_lid');
      await _settle(tester);
      expect(scheduler.isHeld, isTrue);

      // A sheet or dialog is pushed without changing the location.
      final context = tester.element(find.byType(ListDetailScreen));
      unawaited(showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 100),
      ));
      await _settle(tester);
      expect(scheduler.isHeld, isTrue);
      Navigator.of(context).pop();
      await _settle(tester);

      router.go('/home');
      await _settle(tester);
      expect(scheduler.isHeld, isFalse);
      expect(find.byType(ListDetailScreen), findsNothing);
    });

    testWidgets('a list screen disposed without a pop still releases',
        (tester) async {
      final scheduler = SyncScheduler();
      var released = 0;
      scheduler.addHoldListener((held) {
        if (!held) released++;
      });
      await _openReal(tester, [_row('a', 'Milk', 0)], scheduler: scheduler);
      expect(scheduler.isHeld, isTrue,
          reason: 'with no router, mounted means visible');

      // The whole tree goes (the app is torn down, a parent rebuilds without
      // the screen): no route pop ever happens.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(scheduler.isHeld, isFalse);
      expect(released, 1);
    });

    testWidgets(
        'an edit of a new line survives its create syncing (the flush on '
        'app pause) and saves under the server id', (tester) async {
      final (:repo, :db) = await _openReal(tester, [_row('a', 'Milk', 0)]);
      final added = await repo.createItemOfflineFirst(
          _lid, const CreateListItemRequest(name: 'Eggs'));
      await _settle(tester);

      await _startEditing(tester, 'Eggs');
      await tester.enterText(_key('item-line-edit-${added.id}'), 'Eggs large');
      await _settle(tester);

      // The app is paused mid-edit: everything queued goes out.
      await repo.drainOutboxOnce();
      await _settle(tester);
      const serverId = 'server-item-1';
      expect(await _stored(repo, added.id), isNull);
      expect(await _stored(repo, serverId), isNotNull);

      final field = tester.widget<TextField>(_key('item-line-edit-$serverId'));
      expect(field.controller!.text, 'Eggs large',
          reason: 'still editing, nothing typed was lost');
      expect(_key('list-edit-accessory'), findsOneWidget);

      await _tapOutside(tester);
      expect((await _stored(repo, serverId))!.name, 'Eggs large');
      expect((await _lastPatch(db, serverId))['name'], 'Eggs large');
    });
  });
}

class _NoLinks implements CanonicalLinkService {
  @override
  Future<String?> resolveHighConfidence(
    String itemName,
    String groupId, {
    List<String> listContext = const [],
    Object? context,
  }) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

ListItemsTableCompanion _row(
  String id,
  String name,
  int position, {
  bool checked = false,
  double quantity = 1,
  String unit = '',
  int? priceCents,
}) =>
    ListItemsTableCompanion(
      id: Value(id),
      listId: const Value(_lid),
      name: Value(name),
      quantity: Value(quantity),
      unit: Value(unit),
      priceCents: Value(priceCents),
      checked: Value(checked),
      position: Value(position),
      createdAt: Value(DateTime.utc(2026, 1, 1)),
      updatedAt: Value(DateTime.utc(2026, 1, 1)),
    );

/// Opens the screen over a real repository and an in-memory database, so
/// undo and redo run through the same offline-first paths as in the app.
Future<({ListRepository repo, AppDatabase db})> _openReal(
  WidgetTester tester,
  List<ListItemsTableCompanion> rows, {
  double width = 390,
  String listName = 'Groceries',
  SyncScheduler? scheduler,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true),
  );
  addTearDown(db.close);
  await db.upsertListsRows([
    ListsTableCompanion(
      id: const Value(_lid),
      groupId: const Value(_gid),
      name: Value(listName),
      type: const Value('todo'),
      createdAt: Value(DateTime.utc(2026, 1, 1)),
      updatedAt: Value(DateTime.utc(2026, 1, 1)),
    ),
  ]);
  await db.upsertListItemsRows(rows);
  final repo =
      ListRepository(db: db, remote: FakeListService(), autoSync: false);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      grocerySeedProvider.overrideWith((ref) async {}),
      listServiceProviderAsync.overrideWith((ref) async => _Service()),
      listRepositoryProvider.overrideWith((ref) async => repo),
      cachedGroupsProvider.overrideWith((ref) async => const []),
      runningLowProvider.overrideWith((ref, id) async => const []),
      bundledGrocerySuggestionServiceProvider.overrideWithValue(_Bundled()),
      canonicalLinkServiceProvider.overrideWithValue(_NoLinks()),
      if (scheduler != null) syncSchedulerProvider.overrideWithValue(scheduler),
    ],
    child: MaterialApp(
      theme: MitlistTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ListDetailScreen(listId: _lid, initialListName: listName),
    ),
  ));
  await _settle(tester);
  // As in [_open]: no server to refresh from, so its note would cover the
  // edit controls.
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .removeCurrentSnackBar(reason: SnackBarClosedReason.remove);
  await _settle(tester);
  return (repo: repo, db: db);
}

Future<void> _menu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('List options'));
  await _settle(tester);
  await tester.tap(find.text(item).last);
  await _settle(tester);
}

IconButton _arrow(WidgetTester tester, String key) =>
    tester.widget<IconButton>(find.byKey(ValueKey(key)));

Future<ListItem?> _stored(ListRepository repo, String id) async =>
    (await repo.getItemsByListOnce(_lid)).where((i) => i.id == id).firstOrNull;

/// The patch of the newest queued edit of [itemId].
Future<Map<String, dynamic>> _lastPatch(AppDatabase db, String itemId) async {
  final ops = [
    for (final op in await db.getOutboxOpsByType('updateItem'))
      if ((jsonDecode(op.payloadJson) as Map)['itemId'] == itemId)
        jsonDecode(op.payloadJson) as Map<String, dynamic>,
  ];
  return Map<String, dynamic>.from(ops.last['patch'] as Map);
}

/// The keyboard is up: the body ends above it, as on a phone.
void _keyboardUp(WidgetTester tester) {
  tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
}

bool _addLineFocused(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('list-add-line')))
    .focusNode!
    .hasFocus;

Future<Map<String, bool>> _checked(ListRepository repo) async => {
      for (final item in await repo.getItemsByListOnce(_lid))
        item.id: item.checked,
    };

/// The list screen under a GoRouter at `/home` (lists at `/lists/:id`), over
/// a real repository, holding through [scheduler].
Future<GoRouter> _openRouted(
  WidgetTester tester,
  SyncScheduler scheduler,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true),
  );
  addTearDown(db.close);
  await db.upsertListsRows([
    ListsTableCompanion(
      id: const Value(_lid),
      groupId: const Value(_gid),
      name: const Value('Groceries'),
      type: const Value('todo'),
      createdAt: Value(DateTime.utc(2026, 1, 1)),
      updatedAt: Value(DateTime.utc(2026, 1, 1)),
    ),
  ]);
  await db.upsertListItemsRows([_row('a', 'Milk', 0)]);
  final repo =
      ListRepository(db: db, remote: FakeListService(), autoSync: false);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/lists/:listId',
        builder: (context, state) =>
            ListDetailScreen(listId: state.pathParameters['listId']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      grocerySeedProvider.overrideWith((ref) async {}),
      listServiceProviderAsync.overrideWith((ref) async => _Service()),
      listRepositoryProvider.overrideWith((ref) async => repo),
      cachedGroupsProvider.overrideWith((ref) async => const []),
      runningLowProvider.overrideWith((ref, id) async => const []),
      bundledGrocerySuggestionServiceProvider.overrideWithValue(_Bundled()),
      canonicalLinkServiceProvider.overrideWithValue(_NoLinks()),
      syncSchedulerProvider.overrideWithValue(scheduler),
    ],
    child: MaterialApp.router(
      theme: MitlistTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  ));
  await _settle(tester);
  return router;
}
