String formatCurrency(int cents, String currencyCode) {
  final symbol = _currencySymbol(currencyCode);
  final value = (cents / 100).toStringAsFixed(2);
  if (_postfixCurrencies.contains(currencyCode.toUpperCase())) {
    return '$value $symbol';
  }
  return '$symbol$value';
}

String _currencySymbol(String code) {
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
