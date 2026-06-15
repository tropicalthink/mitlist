import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/finance_models.dart';

void main() {
  group('CreateExpenseRequest —', () {
    test('toJson includes base_amount and fx_rate', () {
      final req = CreateExpenseRequest(
        groupId: 'g1',
        payerId: 'p1',
        amount: 10000,
        baseAmount: 11000,
        fxRate: 1.10,
        description: 'Hotel',
        currency: 'EUR',
        date: DateTime.utc(2026, 2, 1),
      );

      final json = req.toJson();
      expect(json['amount'], equals(10000));
      expect(json['base_amount'], equals(11000));
      expect(json['fx_rate'], equals(1.10));
      expect(json['currency'], equals('EUR'));
    });

    test('defaults fx_rate to 1.0', () {
      final req = CreateExpenseRequest(
        groupId: 'g1',
        payerId: 'p1',
        amount: 500,
        baseAmount: 500,
        description: 'Coffee',
        date: DateTime.utc(2026, 2, 1),
      );
      expect(req.fxRate, equals(1.0));
      expect(req.toJson()['fx_rate'], equals(1.0));
    });
  });

  group('Expense.fromJson —', () {
    Map<String, dynamic> baseJson() => {
          'id': 'e1',
          'group_id': 'g1',
          'payer_id': 'p1',
          'amount': 10000,
          'base_amount': 11000,
          'fx_rate': 1.10,
          'description': 'Hotel',
          'category': 'travel',
          'currency': 'EUR',
          'notes': '',
          'date': '2026-02-01T00:00:00.000Z',
          'created_at': '2026-02-01T00:00:00.000Z',
        };

    test('round-trips base_amount and fx_rate', () {
      final e = Expense.fromJson(baseJson());
      expect(e.amount, equals(10000));
      expect(e.baseAmount, equals(11000));
      expect(e.fxRate, equals(1.10));

      final json = e.toJson();
      expect(json['base_amount'], equals(11000));
      expect(json['fx_rate'], equals(1.10));
    });

    test('absent fx_rate defaults to 1.0', () {
      final json = baseJson()..remove('fx_rate');
      final e = Expense.fromJson(json);
      expect(e.fxRate, equals(1.0));
    });

    test('absent base_amount falls back to amount (parseJsonInt64 path)', () {
      // base_amount absent and amount provided as a JSON string (int64 wire
      // form) should still parse via the same int64 helper as amount.
      final json = baseJson()
        ..remove('base_amount')
        ..['amount'] = '7500';
      final e = Expense.fromJson(json);
      expect(e.amount, equals(7500));
      expect(e.baseAmount, equals(7500));
    });
  });
}
