import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/initial_sync_provider.dart';
import 'package:mitlist/providers/outbox_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'a cold start known offline skips the pull, then runs it once the '
      'network is back', () async {
    final connectivity = FakeConnectivityService(initiallyOnline: false);
    var repoReads = 0;
    final container = ProviderContainer(overrides: [
      connectivityServiceProvider.overrideWithValue(connectivity),
      // Stands in for every refresh: counts how often the pull got that far.
      groupRepositoryProvider.overrideWith((ref) async {
        repoReads++;
        throw StateError('no server in this test');
      }),
    ]);
    addTearDown(container.dispose);
    addTearDown(connectivity.dispose);

    await container.read(initialSyncProvider.notifier).start();
    expect(container.read(initialSyncProvider), InitialSyncStatus.failed);
    expect(repoReads, 0, reason: 'nothing is pulled while known offline');

    connectivity.setOnline(true);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(repoReads, 1, reason: 'the retry runs when the network returns');
  });
}
