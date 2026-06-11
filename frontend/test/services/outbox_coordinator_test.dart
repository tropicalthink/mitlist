import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
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
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

// ---------------------------------------------------------------------------
// Minimal concrete-class fakes for repo constructors (no real network I/O).
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Spy wrappers — override drainOutboxOnce to record call counts without hitting
// real API or DB logic.
// ---------------------------------------------------------------------------

class _SpyListRepository extends ListRepository {
  int drainCalls = 0;

  _SpyListRepository(AppDatabase db) : super(db: db, remote: FakeListService());

  @override
  Future<void> drainOutboxOnce() async => drainCalls++;
}

class _SpyFinanceRepository extends FinanceRepository {
  int drainCalls = 0;

  _SpyFinanceRepository(AppDatabase db)
      : super(db: db, remote: FakeFinanceService());

  @override
  Future<void> drainOutboxOnce() async => drainCalls++;
}

class _SpyRecipeRepository extends RecipeRepository {
  int drainCalls = 0;

  _SpyRecipeRepository(AppDatabase db)
      : super(db: db, remote: _FakeRecipeService());

  @override
  Future<void> drainOutboxOnce() async => drainCalls++;
}

class _SpyChoreRepository extends ChoreRepository {
  int drainCalls = 0;

  _SpyChoreRepository(AppDatabase db)
      : super(db: db, remote: _FakeChoreService());

  @override
  Future<void> drainOutboxOnce() async => drainCalls++;
}

class _SpyPinwallRepository extends PinwallRepository {
  int drainCalls = 0;

  _SpyPinwallRepository(AppDatabase db)
      : super(db: db, remote: _FakePinwallService());

  @override
  Future<void> drainOutboxOnce() async => drainCalls++;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

typedef _Spies = ({
  _SpyListRepository list,
  _SpyFinanceRepository finance,
  _SpyRecipeRepository recipe,
  _SpyChoreRepository chore,
  _SpyPinwallRepository pinwall,
});

({OutboxCoordinator coordinator, _Spies spies, AppDatabase db}) _build(
    FakeConnectivityService connectivity) {
  final db = _memoryDb();
  final spies = (
    list: _SpyListRepository(db),
    finance: _SpyFinanceRepository(db),
    recipe: _SpyRecipeRepository(db),
    chore: _SpyChoreRepository(db),
    pinwall: _SpyPinwallRepository(db),
  );
  final coordinator = OutboxCoordinator(
    db: db,
    connectivity: connectivity,
    listRepo: spies.list,
    financeRepo: spies.finance,
    recipeRepo: spies.recipe,
    choreRepo: spies.chore,
    pinwallRepo: spies.pinwall,
  );
  return (coordinator: coordinator, spies: spies, db: db);
}

void main() {
  group('OutboxCoordinator —', () {
    late FakeConnectivityService connectivity;

    setUp(() {
      connectivity = FakeConnectivityService(initiallyOnline: false);
    });

    tearDown(() => connectivity.dispose());

    // -------------------------------------------------------------------------
    // Case 1: drain() while offline — no repos drained
    // -------------------------------------------------------------------------
    test('drain() while offline: no repo drainOutboxOnce calls made', () async {
      final (:coordinator, :spies, :db) = _build(connectivity);
      addTearDown(db.close);

      await coordinator.drain();

      expect(spies.list.drainCalls, equals(0));
      expect(spies.finance.drainCalls, equals(0));
      expect(spies.recipe.drainCalls, equals(0));
      expect(spies.chore.drainCalls, equals(0));
      expect(spies.pinwall.drainCalls, equals(0));
    });

    // -------------------------------------------------------------------------
    // Case 2: drain() while online — all repos drained in order
    // -------------------------------------------------------------------------
    test('drain() while online: all repos drained exactly once', () async {
      connectivity = FakeConnectivityService(initiallyOnline: true);
      final (:coordinator, :spies, :db) = _build(connectivity);
      addTearDown(db.close);

      await coordinator.drain();

      expect(spies.list.drainCalls, equals(1));
      expect(spies.finance.drainCalls, equals(1));
      expect(spies.recipe.drainCalls, equals(1));
      expect(spies.chore.drainCalls, equals(1));
      expect(spies.pinwall.drainCalls, equals(1));
    });

    // -------------------------------------------------------------------------
    // Case 3: _isDraining guard — pins current behavior
    //
    // KNOWN BUG: _isDraining is set only AFTER `isOnline()` returns, so two
    // synchronously-launched drain() calls both pass the initial `if (_isDraining)`
    // guard before either sets the flag. As a result two concurrent drain() calls
    // do NOT collapse; both run through the repo drains.
    //
    // This test pins CURRENT behavior. The guard would work correctly only if
    // _isDraining were set to true before the first await.
    // -------------------------------------------------------------------------
    test(
        'KNOWN BUG: two concurrent drain() calls both proceed (_isDraining set after await)',
        () async {
      connectivity = FakeConnectivityService(initiallyOnline: true);
      final (:coordinator, :spies, :db) = _build(connectivity);
      addTearDown(db.close);

      // Launch two drains without awaiting the first.
      final f1 = coordinator.drain();
      final f2 = coordinator.drain();
      await Future.wait([f1, f2]);

      // KNOWN BUG: current code sets _isDraining only after the first await
      // (isOnline()), so both calls proceed and each repo is drained twice.
      expect(spies.list.drainCalls, equals(2),
          reason:
              'KNOWN BUG: _isDraining is set after isOnline() so both calls '
              'proceed; should be 1 after fix');
      expect(spies.finance.drainCalls, equals(2));
    });

    // -------------------------------------------------------------------------
    // Case 4: connectivity emits online → drain triggered automatically
    // -------------------------------------------------------------------------
    test('start(): connectivity coming online triggers a drain', () async {
      connectivity = FakeConnectivityService(initiallyOnline: false);
      final (:coordinator, :spies, :db) = _build(connectivity);
      addTearDown(db.close);

      coordinator.start();
      // Give the initial isOnline() check time to run (offline, so no drain).
      await Future<void>.delayed(Duration.zero);

      expect(spies.list.drainCalls, equals(0));

      // Emit online signal.
      connectivity.setOnline(true);
      // Let the async listener fire and drain complete.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(spies.list.drainCalls, equals(1),
          reason: 'coming online should trigger one drain pass');
      expect(spies.finance.drainCalls, equals(1));
    });

    // -------------------------------------------------------------------------
    // Case 5: start() initial drain when already online
    // -------------------------------------------------------------------------
    test('start(): triggers initial drain if already online at startup',
        () async {
      connectivity = FakeConnectivityService(initiallyOnline: true);
      final (:coordinator, :spies, :db) = _build(connectivity);
      addTearDown(db.close);

      coordinator.start();
      // Allow the async isOnline() future to resolve.
      await Future<void>.delayed(Duration.zero);
      // Drain is async too, give it another tick.
      await Future<void>.delayed(Duration.zero);

      expect(spies.list.drainCalls, greaterThanOrEqualTo(1),
          reason: 'start() should drain immediately if already online');
    });

    // -------------------------------------------------------------------------
    // Case 6: dispose() cleans up without error (pins current dispose behavior)
    // -------------------------------------------------------------------------
    test('dispose() does not throw', () async {
      final (:coordinator, :spies, :db) = _build(connectivity);
      addTearDown(db.close);

      coordinator.start();
      expect(() => coordinator.dispose(), returnsNormally);
    });
  });
}
