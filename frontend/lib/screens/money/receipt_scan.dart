import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/scan/receipt_parser.dart';
import '../../sheets/expense_creation_sheet.dart';
import '../../widgets/app_toast.dart';
import '../scanner/document_photo_reader.dart';

/// How old a printed date may be and still be taken as when the expense
/// happened; anything older is far more likely a misread than a find.
const Duration kReceiptDateWindow = Duration(days: 365);

/// Photographs a till receipt, reads it on the device and opens the expense
/// sheet filled in from it: the store, the total, the date, the lines in the
/// notes and the photo attached. Everything stays editable; returns what the
/// sheet returns.
Future<bool?> scanReceiptToExpense(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final photo = await captureDocumentPhoto(
    context,
    ref,
    title: l10n.receiptScanTitle,
    readingMessage: l10n.receiptScanReading,
  );
  if (photo == null || !context.mounted) return null;

  final now = DateTime.now();
  final reading = const ReceiptParser().parse(
    photo.lines,
    now: now,
    // Slashed dates are ambiguous; the device's region says which way round.
    monthFirst:
        WidgetsBinding.instance.platformDispatcher.locale.countryCode == 'US',
  );
  final amount = reading.amountCents;
  final date = reading.date;
  if (amount == null) {
    AppToast.info(context, l10n.receiptScanNoTotal);
  } else if (reading.items.isNotEmpty && !reading.itemsMatchTotal) {
    AppToast.info(context, l10n.receiptScanCheckTotal);
  }

  return ExpenseCreationSheet.show(
    context,
    initialDescription: reading.store,
    initialAmount: amount == null || amount <= 0
        ? null
        : (amount / 100).toStringAsFixed(2),
    initialDate: date != null &&
            !date.isAfter(now) &&
            now.difference(date) <= kReceiptDateWindow
        ? date
        : null,
    initialNotes: receiptNotes(reading),
    receiptImage: File(photo.capture.originalPath),
  );
}

/// The receipt's lines as expense notes, one per line, so a split can be
/// worked out later without the paper.
String? receiptNotes(ReceiptReading reading) {
  if (reading.items.isEmpty) return null;
  return reading.items
      .map((item) =>
          '${item.name} ${(item.amountCents / 100).toStringAsFixed(2)}')
      .join('\n');
}
