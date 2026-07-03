import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/repositories/grocery_repository.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/screens/scanner/scan_review_screen.dart';
import 'package:mitlist/services/list_service.dart';
import 'package:mitlist/services/scan/canonical_resolver_service.dart';
import 'package:mitlist/services/scan/scan_models.dart';
import 'package:mitlist/storage/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';

  late AppDatabase db;
  late _FakeListService listService;
  late _FakeListRepository listRepository;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    listService = _FakeListService(groupId: groupId);
    listRepository = _FakeListRepository(listService);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('adds scanned items directly to the target list', (tester) async {
    await _setLargeSurface(tester);
    await _pumpReview(
      tester,
      db: db,
      listService: listService,
      listRepository: listRepository,
      scanResult: const GroceryScanResult(
        items: [
          GroceryPrediction(
            id: 'p1',
            rawText: 'mlk',
            displayName: 'Milk',
            canonicalItemId: 'milk',
            confidenceLevel: ConfidenceLevel.autoAccept,
            confidenceScore: 1,
          ),
        ],
      ),
      targetListId: 'list-existing',
      targetListName: 'Groceries',
    );

    await tester.tap(find.text('1 ITEM'));
    await tester.pump();

    expect(listRepository.createItemCalls, hasLength(1));
    final call = listRepository.createItemCalls.single;
    expect(call.listId, 'list-existing');
    expect(call.request.name, 'Milk');
    expect(call.request.canonicalItemId, 'milk');
  });

  testWidgets('New list creates a list before adding scanned items',
      (tester) async {
    await _setLargeSurface(tester);
    await _pumpReview(
      tester,
      db: db,
      listService: listService,
      listRepository: listRepository,
      scanResult: const GroceryScanResult(
        items: [
          GroceryPrediction(
            id: 'p1',
            rawText: 'egz',
            displayName: 'Eggs',
            canonicalItemId: 'eggs',
            confidenceLevel: ConfidenceLevel.autoAccept,
            confidenceScore: 1,
          ),
        ],
      ),
    );

    await tester.tap(find.text('1 ITEM ADD TO LIST'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New list…'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Weekend shop');
    await tester.tap(find.text('CREATE LIST'));
    await tester.pump();

    expect(listService.createdLists, hasLength(1));
    expect(listService.createdLists.single.name, 'Weekend shop');
    expect(listRepository.createItemCalls, hasLength(1));
    final call = listRepository.createItemCalls.single;
    expect(call.listId, 'list-created-1');
    expect(call.request.name, 'Eggs');
    expect(call.request.canonicalItemId, 'eggs');
  });

  testWidgets('ask row leads with OCR text and shows best-guess subtitle',
      (tester) async {
    await _setLargeSurface(tester);
    await _pumpReview(
      tester,
      db: db,
      listService: listService,
      listRepository: listRepository,
      scanResult: const GroceryScanResult(
        items: [
          GroceryPrediction(
            id: 'p1',
            rawText: 'olive oil',
            displayName: 'Onion',
            canonicalItemId: 'onion',
            confidenceLevel: ConfidenceLevel.ask,
            confidenceScore: 0.2,
          ),
        ],
      ),
      targetListId: 'list-existing',
      targetListName: 'Groceries',
    );

    expect(find.text('olive oil'), findsOneWidget);
    expect(find.text('Best guess: Onion'), findsOneWidget);
  });

  testWidgets('alternative chip applies canonical item before adding to list',
      (tester) async {
    await _setLargeSurface(tester);
    await _pumpReview(
      tester,
      db: db,
      listService: listService,
      listRepository: listRepository,
      scanResult: const GroceryScanResult(
        items: [
          GroceryPrediction(
            id: 'p1',
            rawText: 'ot milk',
            displayName: 'Milk',
            canonicalItemId: 'milk',
            confidenceLevel: ConfidenceLevel.review,
            confidenceScore: 0.7,
            alternatives: [
              ResolveAlternative(
                canonicalItemId: 'oat-milk',
                displayName: 'Oat Milk',
              ),
            ],
          ),
        ],
      ),
      targetListId: 'list-existing',
      targetListName: 'Groceries',
    );

    expect(find.text('Oat Milk'), findsOneWidget);

    await tester.tap(find.text('Oat Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 ITEM'));
    await tester.pump();

    expect(listRepository.createItemCalls, hasLength(1));
    final call = listRepository.createItemCalls.single;
    expect(call.listId, 'list-existing');
    expect(call.request.name, 'Oat Milk');
    expect(call.request.canonicalItemId, 'oat-milk');
  });

  testWidgets('autoAccept row headline is displayName unchanged',
      (tester) async {
    await _setLargeSurface(tester);
    await _pumpReview(
      tester,
      db: db,
      listService: listService,
      listRepository: listRepository,
      scanResult: const GroceryScanResult(
        items: [
          GroceryPrediction(
            id: 'p1',
            rawText: 'mlk',
            displayName: 'Milk',
            canonicalItemId: 'milk',
            confidenceLevel: ConfidenceLevel.autoAccept,
            confidenceScore: 1,
          ),
        ],
      ),
      targetListId: 'list-existing',
      targetListName: 'Groceries',
    );

    expect(find.text('Milk'), findsOneWidget);
  });
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required AppDatabase db,
  required _FakeListService listService,
  required _FakeListRepository listRepository,
  required GroceryScanResult scanResult,
  String? targetListId,
  String? targetListName,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        listServiceProviderAsync.overrideWith((ref) async => listService),
        listRepositoryProvider.overrideWith((ref) async => listRepository),
        groceryRepositoryProvider.overrideWith(
          (ref) async => _FakeGroceryRepository(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScanReviewScreen(
          scanResult: scanResult,
          groupId: '11111111-1111-1111-1111-111111111111',
          userId: '22222222-2222-2222-2222-222222222222',
          targetListId: targetListId,
          targetListName: targetListName,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setLargeSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _CreateItemCall {
  const _CreateItemCall(this.listId, this.request);
  final String listId;
  final CreateListItemRequest request;
}

class _FakeListRepository implements ListRepository {
  _FakeListRepository(this._service);

  final _FakeListService _service;
  final List<_CreateItemCall> createItemCalls = [];

  @override
  Future<List<ItemList>> getListsByGroupOnce(String groupId) async =>
      _service.lists;

  @override
  Future<int> refreshLists(String groupId,
      {int limit = 200, int offset = 0}) async {
    return _service.lists.length;
  }

  @override
  Future<ListItem> createItemOfflineFirst(
    String listId,
    CreateListItemRequest req,
  ) async {
    createItemCalls.add(_CreateItemCall(listId, req));
    final now = DateTime.utc(2026, 1, 1);
    return ListItem(
      id: 'item-${createItemCalls.length}',
      listId: listId,
      name: req.name,
      quantity: req.quantity,
      unit: req.unit,
      canonicalItemId: req.canonicalItemId,
      checked: false,
      position: createItemCalls.length - 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} not implemented on _FakeListRepository',
      );
}

class _FakeListService implements ListService {
  _FakeListService({required this.groupId}) {
    final now = DateTime.utc(2026, 1, 1);
    lists.add(ItemList(
      id: 'list-existing',
      groupId: groupId,
      name: 'Groceries',
      type: 'shopping',
      itemCount: 0,
      createdAt: now,
      updatedAt: now,
    ));
  }

  final String groupId;
  final List<ItemList> lists = [];
  final List<CreateListRequest> createdLists = [];

  @override
  Future<List<ItemList>> listLists(String groupId,
      {int limit = 50, int offset = 0}) async {
    return lists.skip(offset).take(limit).toList();
  }

  @override
  Future<ItemList> createList(CreateListRequest req) async {
    createdLists.add(req);
    final now = DateTime.utc(2026, 1, 1);
    final list = ItemList(
      id: 'list-created-${createdLists.length}',
      groupId: req.groupId,
      name: req.name,
      type: req.type,
      itemCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    lists.add(list);
    return list;
  }

  @override
  Future<List<ShoppingLocation>> listShoppingLocations(String groupId) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} not implemented on _FakeListService',
      );
}

class _FakeGroceryRepository implements GroceryRepository {
  @override
  Future<int> uploadCorrection({
    required String groupId,
    required String rawText,
    required String canonicalItemId,
    String kind = 'alias',
    String lang = '',
    String scope = 'household',
  }) async =>
      1;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} not implemented on _FakeGroceryRepository',
      );
}
