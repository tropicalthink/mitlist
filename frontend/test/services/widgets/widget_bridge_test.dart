import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/providers/home_widgets_provider.dart';
import 'package:mitlist/providers/widget_discovery_provider.dart';
import 'package:mitlist/services/widgets/home_widget_kind.dart';
import 'package:mitlist/services/widgets/widget_bridge.dart';

import 'fake_widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(WidgetBridge.channelName);
  late List<MethodCall> calls;
  Object? installedReply;

  setUp(() {
    calls = [];
    installedReply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      // Let concurrent callers pile up while a call is in flight.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (call.method == 'installedWidgets') return installedReply;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  WidgetBridge bridge() => WidgetBridge(isSupported: true);

  group('clearAll', () {
    test('sign-out sends no arguments; concurrent ones share one call',
        () async {
      final b = bridge();
      await Future.wait([b.clearAll(), b.clearAll(), b.clearAll()]);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'clearAll');
      expect(calls.single.arguments, isNull);
    });

    test('a not-remembered session sends its reason', () async {
      await bridge().clearAll(reason: WidgetBridge.clearReasonNotRemembered);
      expect(calls.single.arguments, {'reason': 'not_remembered'});
    });

    test('a reason is not swallowed by a plain clear in flight', () async {
      final b = bridge();
      final plain = b.clearAll();
      final remembered =
          b.clearAll(reason: WidgetBridge.clearReasonNotRemembered);
      final again = b.clearAll(reason: WidgetBridge.clearReasonNotRemembered);
      await Future.wait([plain, remembered, again]);
      expect(calls.map((c) => c.arguments).toList(), [
        null,
        {'reason': 'not_remembered'},
      ]);
    });

    test('nor a plain clear by one with a reason', () async {
      final b = bridge();
      await Future.wait([
        b.clearAll(reason: WidgetBridge.clearReasonNotRemembered),
        b.clearAll(),
      ]);
      expect(calls.map((c) => c.arguments).toList(), [
        {'reason': 'not_remembered'},
        null,
      ]);
    });

    test('a later clear is a new call', () async {
      final b = bridge();
      await b.clearAll();
      await b.clearAll();
      expect(calls, hasLength(2));
    });
  });

  group('installed widget kinds', () {
    test('the bridge drops entries that are not strings', () async {
      installedReply = <Object?>['chores', 42, null, 'balance'];
      expect(await bridge().installedWidgets(), ['chores', 'balance']);
    });

    test('unknown kind strings are ignored, never thrown on', () async {
      expect(
        HomeWidgetKind.parseAll(
          const ['shopping_list', 'balance', 'controls', '', 'household'],
        ),
        [HomeWidgetKind.shoppingList, HomeWidgetKind.household],
      );
      expect(HomeWidgetKind.fromId('balance'), isNull);
    });

    test('the discovery provider reports known kinds only', () async {
      final fake = FakeWidgetBridge()
        ..installed = const ['balance', 'household', 'controls', 'chores'];
      final container = ProviderContainer(
        overrides: [widgetBridgeProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(installedHomeWidgetsProvider.future),
        ['household', 'chores'],
      );

      fake.installed = const ['balance'];
      container.invalidate(installedHomeWidgetsProvider);
      expect(await container.read(installedHomeWidgetsProvider.future), []);

      fake.installed = null;
      container.invalidate(installedHomeWidgetsProvider);
      expect(await container.read(installedHomeWidgetsProvider.future), isNull);
    });

    test('quick add is offered on iOS and Android alike', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(
          HomeWidgetKind.availableOn(platform),
          contains(HomeWidgetKind.quickAdd),
        );
      }
    });
  });
}
