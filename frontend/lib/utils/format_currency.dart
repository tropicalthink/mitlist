String formatCurrency(int cents, String currencyCode) {
  final isNegative = cents < 0;
  final absCents = cents.abs().clamp(0, 999999999);
  final symbol = currencySymbol(currencyCode);
  final value = (absCents / 100).toStringAsFixed(2);
  final prefix = isNegative ? '-' : '';
  if (_postfixCurrencies.contains(currencyCode.toUpperCase())) {
    return '$prefix$value $symbol';
  }
  return '$prefix$symbol$value';
}

String currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '\u{20AC}';
    case 'GBP':
      return '\u{00A3}';
    case 'JPY':
      return '\u{00A5}';
    case 'CAD':
      return 'C\$';
    case 'AUD':
      return 'A\$';
    case 'CHF':
      return 'Fr';
    case 'SEK':
      return 'kr';
    case 'NOK':
      return 'kr';
    case 'DKK':
      return 'kr';
    case 'PLN':
      return 'z\u{0142}';
    case 'CZK':
      return 'K\u{010D}';
    case 'HUF':
      return 'Ft';
    default:
      return '$code ';
  }
}

const _postfixCurrencies = {
  'SEK',
  'NOK',
  'DKK',
  'PLN',
  'CZK',
};
