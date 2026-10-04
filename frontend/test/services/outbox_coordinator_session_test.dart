import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/repositories/chore_repository.dart';
import 'package:mitlist/repositories/finance_repository.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/repositories/pinwall_repository.dart';
import 'package:mitlist/repositories/recipe_repository.dart';
import 'package:mitlist/services/chore_service.dart';
import 'package:mitlist/services/outbox_coordinator.dart';
import 'package:mitlist/services/pinwall_service.dart';
import 'package:mitlist/services/recipe_service.dart';
import 'package:mitlist/services/sync_scheduler.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

// The sync session is timer-driven, so these run under testWidgets: its
// FakeAsync zone lets `tester.pump(duration)` advance the idle window exactly.

class _FakeRecipeService implements RecipeService {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeChoreService implements ChoreService {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakePinwallService implements PinwallService {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

/// Counts coordinator drain passes (the list repo drains first in each one).
class _SpyListRepository extends ListRepository {
  int drainCalls = 0;
  _SpyListRepository(AppDatabase db) : super(db: db, remote: FakeListService());
  @override
  Future<void> drainOutboxOnce() async => drainCalls++;
}

class _QuietFinanceRepository extends FinanceRepository {
  _QuietFinanceRepository(AppDatabase db)
      : super(db: db, remote: FakeFinanceService());
  @override
  Future<void> drainOutboxOnce() async {}
}

class _QuietRecipeRepository extends RecipeRepository {
  _QuietRecipeRepository(AppDatabase db)
      : super(db: db, remote: _FakeRecipeService());
  @override
  Future<void> drainOutboxOnce() async {}
}

class _QuietChoreRepository extends ChoreRepository {
  _QuietChoreRepository(AppDatabase db)
      : super(db: db, remote: _FakeChoreService());
  @override
  Future<void> drainOutboxOnce() async {}
}

class _QuietPinwallRepository extends PinwallRepository {
  _QuietPinwallRepository(AppDatabase db)
      : super(db: db, remote: _FakePinwallService());
  @override
  Future<void> drainOutboxOnce() async {}
}

const _window = Duration(seconds: 20);

void main() {
  late AppDatabase db;
  late FakeConnectivityService connectivity;
  late _SpyListRepository listRepo;
  late OutboxCoordinator coordinator;

  void build() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    connectivity = FakeConnectivityService(initiallyOnline: true);
    listRepo = _SpyListRepository(db);
    coordinator = OutboxCoordinator(
      db: db,
      connectivity: connectivity,
      listRepo: listRepo,
      financeRepo: _QuietFinanceRepository(db),
      recipeRepo: _QuietRecipeRepository(db),
      choreRepo: _QuietChoreRepository(db),
      pinwallRepo: _QuietPinwallRepository(db),
      sessionIdleWindow: _window,
    );
  }

  Future<void> tearDownAll(WidgetTester tester) async {
    coordinator.dispose();
    connectivity.dispose();
    await db.close();
  }

  testWidgets('noteLocalWrite does not drain immediately', (tester) async {
    build();

    coordinator.noteLocalWrite();
    await tester.pump(const Duration(seconds: 1));

    expect(listRepo.drainCalls, 0);
    expect(coordinator.hasPendingSession, isTrue);
    await tearDownAll(tester);
  });

  testWidgets('the idle window drains exactly once', (tester) async {
    build();

    coordinator.noteLocalWrite();
    await tester.pump(_window - const Duration(milliseconds: 1));
    expect(listRepo.drainCalls, 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(listRepo.drainCalls, 1);
    expect(coordinator.hasPendingSession, isFalse);

    // Nothing re-arms on its own: a quiet app stays quiet.
    await tester.pump(_window * 3);
    expect(listRepo.drainCalls, 1);
    await tearDownAll(tester);
  });

  testWidgets('flushSession drains now and disarms the idle timer',
      (tester) async {
    build();

    coordinator.noteLocalWrite();
    await coordinator.flushSession(reason: 'test');
    expect(listRepo.drainCalls, 1);
    expect(coordinator.hasPendingSession, isFalse);

    // The disarmed timer must not fire a second drain later.
    await tester.pump(_window * 2);
    expect(listRepo.drainCalls, 1);
    await tearDownAll(tester);
  });

  testWidgets('a second write before the window elapses extends it',
      (tester) async {
    build();

    coordinator.noteLocalWrite();
    await tester.pump(const Duration(seconds: 15));
    coordinator.noteLocalWrite();

    // 25s after the first write: the original window would have fired.
    await tester.pump(const Duration(seconds: 10));
    expect(listRepo.drainCalls, 0);
    expect(coordinator.hasPendingSession, isTrue);

    // 20s after the second write.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(listRepo.drainCalls, 1);
    await tearDownAll(tester);
  });

  testWidgets('route change flushes only while a session is pending',
      (tester) async {
    build();

    // Quiet app: navigating around never drains.
    coordinator.onLocationChanged('/home');
    coordinator.onLocationChanged('/lists');
    coordinator.onLocationChanged('/lists/abc');
    await tester.pump();
    expect(listRepo.drainCalls, 0);

    // A write on the list, then a location report that did not change
    // (e.g. a listener tick for the same page): still no flush.
    coordinator.noteLocalWrite();
    coordinator.onLocationChanged('/lists/abc');
    await tester.pump();
    expect(listRepo.drainCalls, 0);
    expect(coordinator.hasPendingSession, isTrue);

    // Closing the list ends the session.
    coordinator.onLocationChanged('/lists');
    await tester.pump();
    expect(listRepo.drainCalls, 1);
    expect(coordinator.hasPendingSession, isFalse);

    // Further navigation with nothing queued stays quiet.
    coordinator.onLocationChanged('/home');
    await tester.pump(_window * 2);
    expect(listRepo.drainCalls, 1);
    await tearDownAll(tester);
  });

  testWidgets('SyncScheduler replays a write noted before the coordinator',
      (tester) async {
    build();
    final scheduler = SyncScheduler();

    // A repository write before the coordinator exists.
    scheduler.noteLocalWrite();
    scheduler.attach(coordinator.noteLocalWrite);
    expect(coordinator.hasPendingSession, isTrue);
    expect(listRepo.drainCalls, 0);

    await tester.pump(_window);
    await tester.pump();
    expect(listRepo.drainCalls, 1);

    // Detached: later writes no longer reach the coordinator.
    scheduler.detach(coordinator.noteLocalWrite);
    scheduler.noteLocalWrite();
    expect(coordinator.hasPendingSession, isFalse);
    await tearDownAll(tester);
  });

  test('a repository with onLocalWrite queues and notifies, never drains',
      () async {
    final memDb = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(memDb.close);
    var notes = 0;
    final remote = FakeListService();
    final repo = ListRepository(
      db: memDb,
      remote: remote,
      onLocalWrite: () => notes++,
    );
    await memDb.upsertListsRows([
      ListsTableCompanion(
        id: const drift.Value('list-1'),
        groupId: const drift.Value('group-1'),
        name: const drift.Value('My List'),
        type: const drift.Value('shopping'),
        createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
        updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
      ),
    ]);
    await memDb.upsertListItemsRows([
      ListItemsTableCompanion(
        id: const drift.Value('item-1'),
        listId: const drift.Value('list-1'),
        name: const drift.Value('Bread'),
        quantity: const drift.Value(1.0),
        unit: const drift.Value(''),
        checked: const drift.Value(false),
        position: const drift.Value(0),
        createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
        updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
      ),
    ]);

    await repo.updateItemOfflineFirst(
        'list-1', 'item-1', const UpdateListItemRequest(checked: true));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(notes, 1);
    expect(remote.updateItemCalls, isEmpty);
    expect(await memDb.outboxCount(), greaterThan(0));
  });
}
