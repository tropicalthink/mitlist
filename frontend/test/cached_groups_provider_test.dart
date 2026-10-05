import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show appDatabaseProvider;
import 'package:mitlist/storage/app_database.dart';

void main() {
  test('cachedGroupsProvider skips fetch while signed out', () async {
    var fetchCount = 0;

    // In memory: the app's own database lives on disk behind a background
    // isolate, which made the test process exit uncleanly now and then.
    final db = AppDatabase(drift.DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        groupServiceProviderAsync.overrideWith((ref) async {
          fetchCount++;
          throw StateError('listGroups should not run while signed out');
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(cachedGroupsProvider.future),
      isEmpty,
    );
    expect(fetchCount, 0);

    container.read(authStateProvider.notifier).state = true;
    expect(
      () => container.read(cachedGroupsProvider.future),
      throwsStateError,
    );
    expect(fetchCount, 1);
  });
}
