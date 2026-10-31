import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/screens/money/receipt_scan.dart';
import 'package:mitlist/services/scan/receipt_parser.dart';

void main() {
  final now = DateTime(2026, 10, 31, 18, 30);

  test('a printed date becomes the expense date only when plausible', () {
    expect(receiptExpenseDate(DateTime(2026, 10, 28), now: now),
        DateTime(2026, 10, 28));
    expect(receiptExpenseDate(null, now: now), isNull);
    // A misread into the future or a receipt from years ago keeps today.
    expect(receiptExpenseDate(DateTime(2026, 11, 2), now: now), isNull);
    expect(receiptExpenseDate(DateTime(2019, 5, 4), now: now), isNull);
  });

  test('purchases are dated when the receipt says they happened', () {
    expect(receiptPurchaseTime(null, now: now), now);
    expect(receiptPurchaseTime(DateTime(2026, 10, 31), now: now), now);
    expect(receiptPurchaseTime(DateTime(2026, 10, 28), now: now),
        DateTime(2026, 10, 28, 12));
  });

  test('the lines go into the notes with their prices', () {
    expect(
      receiptNotes(const ReceiptReading(items: [
        ReceiptItem(name: 'Gemüsemais', amountCents: 98),
        ReceiptItem(name: 'OFFER', amountCents: -198, isAdjustment: true),
      ])),
      'Gemüsemais 0.98\nOFFER -1.98',
    );
    expect(receiptNotes(const ReceiptReading()), isNull);
  });
}
