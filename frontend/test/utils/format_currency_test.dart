import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/utils/format_currency.dart';

// Backend and frontend amount entry currently store entered amounts as cents,
// including for zero-decimal currencies. Display still divides by 100, but
// zero-decimal currencies render without fractional digits.

void main() {
  group('formatCurrency', () {
    test('keeps decimal currency behavior', () {
      expect(formatCurrency(12345, 'USD'), r'$123.45');
    });

    test('formats zero-decimal currencies without minor units', () {
      expect(formatCurrency(50000, 'JPY'), '¥500');
      expect(formatCurrency(120000, 'KRW'), '₩1200');
      expect(formatCurrency(90000, 'HUF'), 'Ft900');
    });

    test('formats negative zero-decimal currencies', () {
      expect(formatCurrency(-50000, 'JPY'), '-¥500');
    });

    test('keeps postfix currency placement', () {
      expect(formatCurrency(12345, 'SEK'), '123.45 kr');
    });
  });
}
