import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/utils/safe_launch.dart';

void main() {
  group('isSafeExternalUrl', () {
    test('accepts http URLs', () {
      expect(isSafeExternalUrl('http://example.com'), isTrue);
      expect(isSafeExternalUrl('http://example.com/path?q=1'), isTrue);
    });

    test('accepts https URLs', () {
      expect(isSafeExternalUrl('https://example.com'), isTrue);
      expect(isSafeExternalUrl('https://www.example.com/recipe/123'), isTrue);
    });

    test('accepts URLs with leading/trailing whitespace', () {
      expect(isSafeExternalUrl('  https://example.com  '), isTrue);
      expect(isSafeExternalUrl('\thttps://example.com\n'), isTrue);
    });

    test('rejects javascript: scheme', () {
      expect(isSafeExternalUrl('javascript:alert(1)'), isFalse);
      expect(isSafeExternalUrl('javascript:void(0)'), isFalse);
    });

    test('rejects file: scheme', () {
      expect(isSafeExternalUrl('file:///etc/passwd'), isFalse);
    });

    test('rejects intent: scheme', () {
      expect(isSafeExternalUrl('intent://example.com#Intent;end'), isFalse);
    });

    test('rejects data: scheme', () {
      expect(isSafeExternalUrl('data:text/html,<h1>hi</h1>'), isFalse);
    });

    test('rejects mailto: scheme', () {
      expect(isSafeExternalUrl('mailto:user@example.com'), isFalse);
    });

    test('rejects empty string', () {
      expect(isSafeExternalUrl(''), isFalse);
    });

    test('rejects garbage input', () {
      expect(isSafeExternalUrl('not a url at all'), isFalse);
      expect(isSafeExternalUrl('://missingscheme'), isFalse);
    });
  });
}
