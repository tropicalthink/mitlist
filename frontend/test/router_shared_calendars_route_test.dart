import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/home_widgets_provider.dart';
import 'package:mitlist/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/widgets/fake_widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('/you/calendars resolves to the Shared calendars page', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        authBootstrapProvider.overrideWith((ref) async => false),
        widgetBridgeProvider.overrideWithValue(FakeWidgetBridge()),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    final match = router.configuration.findMatch(Uri.parse('/you/calendars'));
    expect(match.isError, isFalse);
    expect(match.last.route.name, 'sharedCalendars');
    expect(router.namedLocation('sharedCalendars'), '/you/calendars');
  });
}
