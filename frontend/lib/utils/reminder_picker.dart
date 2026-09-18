import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/app_toast.dart';

/// Asks for a date, then a time, and returns the combined local [DateTime].
///
/// Returns null when the user dismisses either picker. A time that is not at
/// least a minute in the future is rejected with a toast (and null returned),
/// matching the server's "must be in the future" rule so the user never sees
/// a round-trip validation error.
Future<DateTime?> pickReminderDateTime(
  BuildContext context, {
  DateTime? initial,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final seed = reminderPickerSeed(initial, now);
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: seed,
    firstDate: now,
    lastDate: now.add(const Duration(days: 365)),
    helpText: l10n.pinwallChooseReminderDate,
  );
  if (!context.mounted || pickedDate == null) return null;

  final pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(seed),
    helpText: l10n.pinwallChooseReminderTime,
  );
  if (!context.mounted || pickedTime == null) return null;

  final combined = DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );
  if (combined.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
    AppToast.info(context, l10n.pinwallPickFutureTime);
    return null;
  }
  return combined;
}

/// The moment both pickers open on: the existing reminder when it is still
/// in the future, otherwise [now]. Using one seed for the date *and* the time
/// keeps them consistent; previously a reminder that had already fired fell
/// back to today's date but kept its stale time of day.
DateTime reminderPickerSeed(DateTime? initial, DateTime now) {
  if (initial != null && initial.isAfter(now)) return initial.toLocal();
  return now;
}
