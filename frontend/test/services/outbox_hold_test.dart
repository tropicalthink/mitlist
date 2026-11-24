import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

// Outbox holds (the list detail screen holds the outbox while it is open).
// Timer-driven like the session tests, so these run under testWidgets.

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
  late SyncScheduler scheduler;
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
    scheduler = SyncScheduler();
    coordinator = OutboxCoordinator(
      db: db,
      connectivity: connectivity,
      listRepo: listRepo,
      financeRepo: _QuietFinanceRepository(db),
      recipeRepo: _QuietRecipeRepository(db),
      choreRepo: _QuietChoreRepository(db),
      pinwallRepo: _QuietPinwallRepository(db),
      sessionIdleWindow: _window,
      scheduler: scheduler,
    );
    scheduler.attach(coordinator.noteLocalWrite);
  }

  Future<void> tearDownAll(WidgetTester tester) async {
    coordinator.dispose();
    connectivity.dispose();
    await db.close();
  }

  testWidgets('a held outbox ignores every automatic trigger', (tester) async {
    build();
    coordinator.start();
    await tester.pump();
    expect(listRepo.drainCalls, 1, reason: 'the initial drain, unheld');

    final hold = coordinator.hold('list');
    expect(coordinator.isHeld, isTrue);

    // A local write: no idle timer is armed, however long the list is open.
    scheduler.noteLocalWrite();
    await tester.pump(_window * 3);
    // Leaving to another location while still held (a sheet's own route
    // report, say), connectivity coming back, a resume or retry tick.
    coordinator.onLocationChanged('/lists/abc');
    coordinator.onLocationChanged('/lists');
    connectivity.setOnline(false);
    connectivity.setOnline(true);
    await coordinator.drain();
    await tester.pump(const Duration(seconds: 30));
    expect(listRepo.drainCalls, 1);
    expect(coordinator.hasPendingSession, isTrue,
        reason: 'the deferred writes still count as a session');

    hold.release();
    await tester.pump();
    expect(coordinator.isHeld, isFalse);
    expect(listRepo.drainCalls, 2, reason: 'release flushes, once');

    await tester.pump(_window * 2);
    expect(listRepo.drainCalls, 2);
    await tearDownAll(tester);
  });

  testWidgets('release flushes even when nothing was noted', (tester) async {
    build();
    final hold = scheduler.hold('list');
    hold.release();
    await tester.pump();
    expect(listRepo.drainCalls, 1);

    // A second release of the same hold is a no-op.
    hold.release();
    await tester.pump();
    expect(listRepo.drainCalls, 1);
    await tearDownAll(tester);
  });

  testWidgets('a session armed before the hold waits for its release',
      (tester) async {
    build();
    scheduler.noteLocalWrite();
    final hold = coordinator.hold('list');
    await tester.pump(_window * 2);
    expect(listRepo.drainCalls, 0);

    hold.release();
    await tester.pump();
    expect(listRepo.drainCalls, 1);
    await tearDownAll(tester);
  });

  testWidgets('holds nest: only the last release flushes', (tester) async {
    build();
    final outer = scheduler.hold('list a');
    final inner = scheduler.hold('list b');
    scheduler.noteLocalWrite();

    inner.release();
    await tester.pump(_window * 2);
    expect(coordinator.isHeld, isTrue);
    expect(listRepo.drainCalls, 0);

    outer.release();
    await tester.pump();
    expect(listRepo.drainCalls, 1);
    await tearDownAll(tester);
  });

  testWidgets('pausing the app flushes through the hold and keeps it',
      (tester) async {
    build();
    final hold = coordinator.hold('list');
    scheduler.noteLocalWrite();

    // What app.dart does on AppLifecycleState.paused.
    await coordinator.flushSession(reason: 'app paused');
    expect(listRepo.drainCalls, 1);
    expect(coordinator.isHeld, isTrue);

    // Back in the app, still on the list: writes wait again.
    scheduler.noteLocalWrite();
    await coordinator.drain(); // the resume drain
    await tester.pump(_window * 2);
    expect(listRepo.drainCalls, 1);

    hold.release();
    await tester.pump();
    expect(listRepo.drainCalls, 2);
    await tearDownAll(tester);
  });

  testWidgets('a manual retry goes through the hold', (tester) async {
    build();
    final hold = coordinator.hold('list');

    await coordinator.retryFailed();
    expect(listRepo.drainCalls, 1);
    await coordinator.drain(force: true);
    expect(listRepo.drainCalls, 2);
    expect(coordinator.isHeld, isTrue);

    hold.release();
    await tester.pump();
    await tearDownAll(tester);
  });

  testWidgets('a hold taken before the coordinator exists still counts',
      (tester) async {
    // The list screen takes its hold from the scheduler, which the
    // repositories and the screen get before the coordinator is built.
    db = AppDatabase(drift.DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
    connectivity = FakeConnectivityService(initiallyOnline: true);
    listRepo = _SpyListRepository(db);
    scheduler = SyncScheduler();
    final hold = scheduler.hold('list');
    coordinator = OutboxCoordinator(
      db: db,
      connectivity: connectivity,
      listRepo: listRepo,
      financeRepo: _QuietFinanceRepository(db),
      recipeRepo: _QuietRecipeRepository(db),
      choreRepo: _QuietChoreRepository(db),
      pinwallRepo: _QuietPinwallRepository(db),
      sessionIdleWindow: _window,
      scheduler: scheduler,
    );
    scheduler.attach(coordinator.noteLocalWrite);
    expect(coordinator.isHeld, isTrue);
    scheduler.noteLocalWrite();
    await coordinator.drain();
    await tester.pump(_window * 2);
    expect(listRepo.drainCalls, 0);

    hold.release();
    await tester.pump();
    expect(listRepo.drainCalls, 1);
    await tearDownAll(tester);
  });
}
