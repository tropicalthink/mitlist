import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/grocery_seed_loader.dart';
import 'package:mitlist/storage/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('interactive writes interleave with the in-flight grocery seed',
      () async {
    final dir = await Directory.systemTemp.createTemp('seed_probe');
    // Background isolate + file DB, like drift_flutter's driftDatabase in the
    // real app — an in-memory NativeDatabase runs sqlite synchronously on the
    // test isolate and hides the connection-level queueing this test guards.
    final db = AppDatabase(
      NativeDatabase.createInBackground(File('${dir.path}/probe.db')),
    );
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    await db.customStatement(
        'CREATE TABLE IF NOT EXISTS probe (id INTEGER PRIMARY KEY)');

    final seedFuture = GrocerySeedLoader(db).loadIfNeeded();
    var done = false;
    unawaited(seedFuture.whenComplete(() => done = true));

    // Fire an interactive write every second while the seed runs and record
    // how long each waits on the shared connection.
    final waits = <int>[];
    for (var t = 1; t <= 20 && !done; t++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (done) break;
      final w = Stopwatch()..start();
      await db.customStatement('INSERT INTO probe DEFAULT VALUES');
      w.stop();
      waits.add(w.elapsedMilliseconds);
    }
    await seedFuture;

    // ignore: avoid_print
    print('mid-seed write waits (ms): $waits');
    expect(waits, isNotEmpty,
        reason: 'seed finished before any probe write — machine too fast '
            'for this probe to exercise the interleave path');
    // When the seed ran as one giant transaction, EVERY mid-seed write queued
    // for the seed's remaining duration (7+s on desktop). With per-chunk
    // commits, writes slip in between chunks in tens of ms. The minimum is
    // asserted (not each wait) because one legitimate multi-second pause
    // remains: the atomic FTS rebuild — a probe write can land during it.
    expect(waits.reduce((a, b) => a < b ? a : b), lessThan(1000),
        reason: 'no interactive write got through quickly mid-seed — the '
            'seed is monopolizing the connection again');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
