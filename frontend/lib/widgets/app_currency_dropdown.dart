import 'package:flutter/material.dart';

import 'app_dropdown.dart';

const _kCurrencies = <DropdownMenuItem<String>>[
  DropdownMenuItem(value: 'USD', child: Text('USD - US Dollar')),
  DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
  DropdownMenuItem(value: 'GBP', child: Text('GBP - British Pound')),
  DropdownMenuItem(value: 'JPY', child: Text('JPY - Japanese Yen')),
  DropdownMenuItem(value: 'CAD', child: Text('CAD - Canadian Dollar')),
  DropdownMenuItem(value: 'AUD', child: Text('AUD - Australian Dollar')),
  DropdownMenuItem(value: 'CHF', child: Text('CHF - Swiss Franc')),
  DropdownMenuItem(value: 'SEK', child: Text('SEK - Swedish Krona')),
  DropdownMenuItem(value: 'NOK', child: Text('NOK - Norwegian Krone')),
  DropdownMenuItem(value: 'DKK', child: Text('DKK - Danish Krone')),
  DropdownMenuItem(value: 'PLN', child: Text('PLN - Polish Zloty')),
  DropdownMenuItem(value: 'CZK', child: Text('CZK - Czech Koruna')),
  DropdownMenuItem(value: 'HUF', child: Text('HUF - Hungarian Forint')),
];

class AppCurrencyDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?>? onChanged;

  const AppCurrencyDropdown({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppDropdown<String>(
      label: 'Currency',
      value: value,
      items: _kCurrencies,
      onChanged: onChanged,
    );
  }
}
