import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const savedGroupId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'current_group_id': savedGroupId,
    });
  });

  test('ensureLoaded hydrates saved group id from prefs', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(currentGroupIdProvider.notifier);
    expect(container.read(currentGroupIdProvider), isNull);
    expect(notifier.isLoaded, isFalse);

    await notifier.ensureLoaded();

    expect(container.read(currentGroupIdProvider), savedGroupId);
    expect(notifier.isLoaded, isTrue);
  });

  test('set persists after ensureLoaded', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(currentGroupIdProvider.notifier);
    await notifier.ensureLoaded();

    const newId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    await notifier.set(newId);

    expect(container.read(currentGroupIdProvider), newId);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('current_group_id'), newId);
  });
}
