import 'package:intl/intl.dart';

/// Shared currency formatting for the expenses screen and its extracted
/// presentation widgets. Formatters are cached per currency code since
/// `NumberFormat.simpleCurrency` construction is not free.
final Map<String, NumberFormat> _currencyFormats = {};

String formatExpenseCurrency(double value, {String currency = 'USD'}) {
  final key = currency.trim().isEmpty ? 'USD' : currency.trim().toUpperCase();
  final formatter = _currencyFormats.putIfAbsent(key, () {
    try {
      return NumberFormat.simpleCurrency(name: key);
    } catch (_) {
      return NumberFormat.simpleCurrency(name: 'USD');
    }
  });
  return formatter.format(value);
}
