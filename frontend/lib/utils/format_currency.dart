String formatCurrency(int cents, String currencyCode) {
  final isNegative = cents < 0;
  final absCents = cents.abs().clamp(0, 999999999);
  final code = currencyCode.toUpperCase();
  final symbol = currencySymbol(currencyCode);
  final value = _zeroDecimalCurrencies.contains(code)
      ? (absCents / 100).toStringAsFixed(0)
      : (absCents / 100).toStringAsFixed(2);
  final prefix = isNegative ? '-' : '';
  if (_postfixCurrencies.contains(code)) {
    return '$prefix$value $symbol';
  }
  return '$prefix$symbol$value';
}

/// Single source of truth for currency glyphs across the app (money screens via
/// [formatCurrency], list screens directly). Unknown codes fall back to the
/// code itself with a trailing space so it reads cleanly as a prefix.
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
      return 'CA\$';
    case 'AUD':
      return 'A\$';
    case 'NZD':
      return 'NZ\$';
    case 'CHF':
      return 'CHF';
    case 'CNY':
      return '\u{00A5}';
    case 'HKD':
      return 'HK\$';
    case 'SGD':
      return 'S\$';
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
    case 'INR':
      return '\u{20B9}';
    case 'BRL':
      return 'R\$';
    case 'MXN':
      return 'MX\$';
    case 'ZAR':
      return 'R';
    case 'KRW':
      return '\u{20A9}';
    case 'TRY':
      return '\u{20BA}';
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

const _zeroDecimalCurrencies = {
  'BIF',
  'CLP',
  'DJF',
  'GNF',
  'HUF',
  'ISK',
  'JPY',
  'KMF',
  'KRW',
  'PYG',
  'RWF',
  'UGX',
  'VND',
  'VUV',
  'XAF',
  'XOF',
  'XPF',
};
