import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/chore_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show grocerySeedProvider;
import 'package:mitlist/repositories/chore_repository.dart';
import 'package:mitlist/services/chore_service.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/services/household_prior_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/sheets/chore_creation_sheet.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/grocery_seed_test_helper.dart';

class _CapturingSuggestions extends GrocerySuggestionService {
  _CapturingSuggestions(AppDatabase db)
      : super(db, prior: HouseholdPriorService(db));

  GrocerySuggestionContext? context;

  @override
  Future<List<GrocerySuggestion>> suggest(
    String query,
    String groupId, {
    required GrocerySuggestionContext suggestionContext,
    List<String> listContextIds = const [],
    int limit = 8,
  }) async {
    context = suggestionContext;
    return const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';
  final group = Group(
    id: groupId,
    name: 'Test Household',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  testWidgets('adds grocery-aware supplies to the create request',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final groceryDb = memoryDb();
    addTearDown(groceryDb.close);
    final suggestions = _CapturingSuggestions(groceryDb);
    final chores = _FakeChoreService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedGroupsProvider.overrideWith((ref) async => [group]),
          groupServiceProviderAsync.overrideWith(
            (ref) async => _FakeGroupService(),
          ),
          choreServiceProviderAsync.overrideWith((ref) async => chores),
          // The sheet creates through the repository now (offline-first), so
          // that is where the request is captured. The repository→service leg
          // is covered by chore_repository_offline_test.
          choreRepositoryProvider
              .overrideWith((ref) async => _FakeChoreRepository(chores)),
          grocerySeedProvider.overrideWith((ref) async {}),
          grocerySuggestionServiceProvider.overrideWithValue(
            suggestions,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: ChoreCreationSheet()),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.enterText(find.byType(TextField).first, 'Clean kitchen');
    await tester.tap(find.text('More options'));
    await tester.pump(const Duration(milliseconds: 250));
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(1), 'Dish soap');
    await tester.ensureVisible(find.text('ADD'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('ADD'));
    await tester.pump();
    expect(find.text('Dish soap'), findsOneWidget);
    expect(suggestions.context, GrocerySuggestionContext.choreSupply);

    await tester.ensureVisible(find.text('ADD CHORE'));
    await tester.pump();
    await tester.tap(find.text('ADD CHORE'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(chores.lastCreate?.supplies, ['Dish soap']);
  });

  testWidgets('editing sends the full chore back through updateChore',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final groceryDb = memoryDb();
    addTearDown(groceryDb.close);
    final chores = _FakeChoreService();
    final existing = Chore(
      id: '33333333-3333-3333-3333-333333333333',
      groupId: groupId,
      name: 'Water plants',
      description: 'Balcony too',
      rotationType: 'none',
      frequency: 'weekly',
      periodInterval: 2,
      periodConfig: const ['tuesday'],
      trackDateOnly: true,
      rollover: true,
      assignmentType: 'round-robin',
      isActive: true,
      supplies: const ['Watering can'],
      category: 'Plants',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedGroupsProvider.overrideWith((ref) async => [group]),
          groupServiceProviderAsync.overrideWith(
            (ref) async => _FakeGroupService(),
          ),
          choreServiceProviderAsync.overrideWith((ref) async => chores),
          choreRepositoryProvider
              .overrideWith((ref) async => _FakeChoreRepository(chores)),
          grocerySeedProvider.overrideWith((ref) async {}),
          grocerySuggestionServiceProvider.overrideWithValue(
            _CapturingSuggestions(groceryDb),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChoreCreationSheet(existingChore: existing),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Prefilled from the existing chore, and the CTA reads as a save.
    expect(find.text('Water plants'), findsOneWidget);
    expect(find.text('Balcony too'), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Water all plants');
    await tester.ensureVisible(find.text('SAVE'));
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(chores.lastUpdateId, existing.id);
    final req = chores.lastUpdate;
    expect(req?.name, 'Water all plants');
    // The backend PATCH replaces rather than merges, so untouched fields must
    // round-trip unchanged.
    expect(req?.description, 'Balcony too');
    expect(req?.rotationType, 'none');
    expect(req?.frequency, 'weekly');
    expect(req?.periodInterval, 2);
    expect(req?.periodConfig, ['tuesday']);
    expect(req?.trackDateOnly, true);
    expect(req?.rollover, true);
    expect(req?.assignmentType, 'round-robin');
    expect(req?.assignmentConfig, isEmpty);
    expect(req?.supplies, ['Watering can']);
    expect(req?.category, 'Plants');
  });
}

class _FakeGroupService implements GroupService {
  @override
  Future<List<GroupMemberProfile>> listMembers(String groupId) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Captures the create request the sheet builds, delegating to the fake
/// service so the assertion below still reads it from one place.
class _FakeChoreRepository implements ChoreRepository {
  _FakeChoreRepository(this._chores);

  final _FakeChoreService _chores;

  @override
  Future<ChoreCreateResult> createOfflineFirst(
    CreateChoreRequest req, {
    Duration syncWindow = Duration.zero,
  }) async {
    return ChoreCreateResult(
      chore: await _chores.createChore(req),
      synced: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeChoreService implements ChoreService {
  CreateChoreRequest? lastCreate;
  String? lastUpdateId;
  UpdateChoreRequest? lastUpdate;

  @override
  Future<Chore> updateChore(String id, UpdateChoreRequest req) async {
    lastUpdateId = id;
    lastUpdate = req;
    return Chore(
      id: id,
      groupId: 'unused',
      name: req.name ?? '',
      rotationType: req.rotationType ?? 'none',
      frequency: req.frequency ?? 'daily',
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<Chore> createChore(CreateChoreRequest req,
      {String? idempotencyKey}) async {
    lastCreate = req;
    return Chore(
      id: '22222222-2222-2222-2222-222222222222',
      groupId: req.groupId,
      name: req.name,
      rotationType: req.rotationType,
      frequency: req.frequency,
      isActive: true,
      supplies: req.supplies,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
