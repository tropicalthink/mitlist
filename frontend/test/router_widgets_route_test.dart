import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/home_widgets_provider.dart';
import 'package:mitlist/router.dart';
import 'package:mitlist/utils/app_link_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/widgets/fake_widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('/you/widgets resolves to the Widgets page', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        // Signed-out bootstrap: building the router then needs no services.
        authBootstrapProvider.overrideWith((ref) async => false),
        widgetBridgeProvider.overrideWithValue(FakeWidgetBridge()),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    final match = router.configuration.findMatch(Uri.parse('/you/widgets'));
    expect(match.isError, isFalse);
    final route = match.last.route;
    expect(route.name, 'widgets');
    expect(router.namedLocation('widgets'), '/you/widgets');
  });

  test('the widget deep link reaches the router as /you/widgets', () {
    // Flutter hands the router the path of mitlist:///you/widgets; nothing
    // in it is an app-link intent, so the redirect leaves it alone.
    final uri = Uri.parse('mitlist:///you/widgets');
    expect(uri.path, '/you/widgets');
    expect(AppLinkIntent.parse(Uri(path: uri.path)), isNull);
  });
}
