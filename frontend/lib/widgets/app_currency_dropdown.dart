import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_dropdown.dart';

List<DropdownMenuItem<String>> currencyDropdownItems(AppLocalizations l10n) =>
    <DropdownMenuItem<String>>[
      DropdownMenuItem(value: 'USD', child: Text(l10n.currencyUsd)),
      DropdownMenuItem(value: 'EUR', child: Text(l10n.currencyEur)),
      DropdownMenuItem(value: 'GBP', child: Text(l10n.currencyGbp)),
      DropdownMenuItem(value: 'JPY', child: Text(l10n.currencyJpy)),
      DropdownMenuItem(value: 'CAD', child: Text(l10n.currencyCad)),
      DropdownMenuItem(value: 'AUD', child: Text(l10n.currencyAud)),
      DropdownMenuItem(value: 'CHF', child: Text(l10n.currencyChf)),
      DropdownMenuItem(value: 'SEK', child: Text(l10n.currencySek)),
      DropdownMenuItem(value: 'NOK', child: Text(l10n.currencyNok)),
      DropdownMenuItem(value: 'DKK', child: Text(l10n.currencyDkk)),
      DropdownMenuItem(value: 'PLN', child: Text(l10n.currencyPln)),
      DropdownMenuItem(value: 'CZK', child: Text(l10n.currencyCzk)),
      DropdownMenuItem(value: 'HUF', child: Text(l10n.currencyHuf)),
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
    final l10n = AppLocalizations.of(context)!;
    return AppDropdown<String>(
      label: l10n.currencyDropdownLabel,
      value: value,
      items: currencyDropdownItems(l10n),
      onChanged: onChanged,
    );
  }
}
