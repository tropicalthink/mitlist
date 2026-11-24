import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/widgets/widget_bridge.dart';
import 'package:mitlist/services/widgets/widget_promo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetPromoDecision', () {
    final now = DateTime(2026, 11, 22, 9);

    bool decide({
      DateTime? lastShownAt,
      List<String>? installed = const [],
      bool supported = true,
      bool onboardingDone = true,
      DateTime? at,
    }) =>
        WidgetPromoDecision.shouldShow(
          now: at ?? now,
          lastShownAt: lastShownAt,
          installedKinds: installed,
          supported: supported,
          onboardingDone: onboardingDone,
        );

    test('shows the first time once onboarding is done', () {
      expect(decide(), isTrue);
    });

    test('never before onboarding is finished', () {
      expect(decide(onboardingDone: false), isFalse);
      expect(
        decide(
          onboardingDone: false,
          lastShownAt: now.subtract(const Duration(days: 100)),
        ),
        isFalse,
      );
    });

    test('not again after 41 days', () {
      expect(
        decide(lastShownAt: now.subtract(const Duration(days: 41))),
        isFalse,
      );
      expect(
        decide(
          lastShownAt: now.subtract(
            const Duration(days: 42) - const Duration(minutes: 1),
          ),
        ),
        isFalse,
      );
    });

    test('again after 42 days while no widget is installed', () {
      expect(
        decide(lastShownAt: now.subtract(const Duration(days: 42))),
        isTrue,
      );
      expect(
        decide(lastShownAt: now.subtract(const Duration(days: 200))),
        isTrue,
      );
    });

    test('never when a widget is installed', () {
      expect(decide(installed: const ['chores']), isFalse);
      expect(
        decide(
          installed: const ['shopping_list', 'shopping_list'],
          lastShownAt: now.subtract(const Duration(days: 90)),
        ),
        isFalse,
      );
    });

    test('unknown installed state: first showing only', () {
      expect(decide(installed: null), isTrue);
      expect(
        decide(
          installed: null,
          lastShownAt: now.subtract(const Duration(days: 90)),
        ),
        isFalse,
      );
    });

    test('never on a platform without widgets', () {
      expect(decide(supported: false), isFalse);
      expect(
        decide(
          supported: false,
          lastShownAt: now.subtract(const Duration(days: 90)),
        ),
        isFalse,
      );
    });
  });

  group('WidgetPromoStore', () {
    test('round-trips the last showing', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await WidgetPromoStore.lastShownAt(), isNull);
      final at = DateTime(2026, 11, 1, 8, 30);
      await WidgetPromoStore.markShown(at);
      expect(await WidgetPromoStore.lastShownAt(), at);
    });
  });

  group('WidgetBridge discovery methods', () {
    const channel = MethodChannel('test/widgets');
    final calls = <MethodCall>[];

    void handle(Future<Object?>? Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });
    }

    setUp(calls.clear);
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('installedWidgets returns the kinds and keeps duplicates', () async {
      handle((call) async => ['shopping_list', 'chores', 'shopping_list', 7]);
      final bridge = WidgetBridge(channel: channel, isSupported: true);
      expect(
        await bridge.installedWidgets(),
        ['shopping_list', 'chores', 'shopping_list'],
      );
      expect(calls.single.method, 'installedWidgets');
    });

    test('a missing native method reads as unknown and false', () async {
      // No handler: MissingPluginException.
      final bridge = WidgetBridge(channel: channel, isSupported: true);
      expect(await bridge.installedWidgets(), isNull);
      expect(await bridge.isPinWidgetSupported(), isFalse);
      expect(await bridge.pinWidget('chores'), isFalse);
    });

    test('a native failure reads as unknown', () async {
      handle((call) async => throw PlatformException(code: 'boom'));
      final bridge = WidgetBridge(channel: channel, isSupported: true);
      expect(await bridge.installedWidgets(), isNull);
    });

    test('pinWidget sends the kind', () async {
      handle((call) async => true);
      final bridge = WidgetBridge(channel: channel, isSupported: true);
      expect(await bridge.isPinWidgetSupported(), isTrue);
      expect(await bridge.pinWidget('shopping_list'), isTrue);
      expect(calls.last.method, 'pinWidget');
      expect(calls.last.arguments, {'kind': 'shopping_list'});
    });

    test('unsupported platforms never call native code', () async {
      handle((call) async => ['chores']);
      final bridge = WidgetBridge(channel: channel, isSupported: false);
      expect(await bridge.installedWidgets(), isNull);
      expect(await bridge.pinWidget('chores'), isFalse);
      expect(calls, isEmpty);
    });
  });
}
