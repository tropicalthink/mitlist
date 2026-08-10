import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/config/feedback_config.dart';

/// Guards the REQTRACK_URL resolution. The release build always passes
/// `--dart-define=REQTRACK_URL=...`, so an unset CI secret arrives as an empty
/// (but defined) value — which must still fall back to the default host rather
/// than leaving the intake client with an empty base URL.
///
/// Run the empty/override cases with:
///   flutter test --dart-define=REQTRACK_URL= test/feedback_config_test.dart
///   flutter test --dart-define=REQTRACK_URL=https://example.com/ test/...
void main() {
  test('baseUrl is a usable origin with no trailing slash', () {
    expect(FeedbackConfig.baseUrl, isNotEmpty);
    expect(FeedbackConfig.baseUrl, startsWith('https://'));
    expect(FeedbackConfig.baseUrl, isNot(endsWith('/')));
  });

  test('intake URL composes without a doubled slash', () {
    final url = '${FeedbackConfig.baseUrl}${FeedbackConfig.intakePath}';
    expect(url, endsWith('/api/v1/intake/requests'));
    expect(url.split('://').last, isNot(contains('//')));
  });
}
