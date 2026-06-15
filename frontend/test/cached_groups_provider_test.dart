import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/group_provider.dart';

void main() {
  test('cachedGroupsProvider skips fetch while signed out', () async {
    var fetchCount = 0;

    final container = ProviderContainer(
      overrides: [
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
