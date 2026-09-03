import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/utils/open_in_app.dart';

void main() {
  group('appSchemeUri', () {
    test('keeps the path so the router sees /join/<code>', () {
      final uri = appSchemeUri('/join/ABCD-1234');
      expect(uri.toString(), 'mitlist:///join/ABCD-1234');
      expect(uri.scheme, 'mitlist');
      expect(uri.host, isEmpty);
      expect(uri.pathSegments, ['join', 'ABCD-1234']);
    });
  });

  group('openInAppUri', () {
    test('is the plain custom scheme link off Android', () {
      final uri = openInAppUri('/r/tok12345', isAndroid: false);
      expect(uri.toString(), 'mitlist:///r/tok12345');
    });

    test('builds an Android intent URL naming the package', () {
      final uri = openInAppUri('/join/ABCD-1234', isAndroid: true);
      expect(
        uri.toString(),
        'intent:///join/ABCD-1234#Intent;scheme=mitlist;package=me.mitlist;end',
      );
    });

    test('carries an encoded browser fallback on Android', () {
      final uri = openInAppUri(
        '/r/tok12345',
        isAndroid: true,
        fallbackUrl: Uri.parse('https://app.mitlist.me/r/tok12345?x=1'),
      );
      expect(
        uri.toString(),
        'intent:///r/tok12345#Intent;scheme=mitlist;package=me.mitlist;'
        'S.browser_fallback_url=https%3A%2F%2Fapp.mitlist.me%2Fr%2Ftok12345%3Fx%3D1;end',
      );
    });

    test('the fallback is ignored off Android', () {
      final uri = openInAppUri(
        '/join/ABCD-1234',
        isAndroid: false,
        fallbackUrl: Uri.parse('https://app.mitlist.me/join/ABCD-1234'),
      );
      expect(uri.toString(), 'mitlist:///join/ABCD-1234');
    });
  });
}
