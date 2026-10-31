import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/list_provider.dart'
    show appDatabaseProvider, grocerySeedProvider, listRepositoryProvider;
import '../../router.dart' show currentGroupIdProvider;
import '../../services/error_reporter.dart';
import '../../services/scan/receipt_parser.dart';
import '../../services/scan/receipt_purchase_matcher.dart';
import '../../sheets/expense_creation_sheet.dart';
import '../../widgets/app_toast.dart';
import '../scanner/document_photo_reader.dart';

/// How old a printed date may be and still be taken as when the expense
/// happened; anything older is far more likely a misread than a find.
const Duration kReceiptDateWindow = Duration(days: 365);

/// Whether the last receipt's items were recorded as bought; the switch
/// starts where the person left it.
const String kRememberReceiptPurchasesPref = 'receipt_remember_purchases';

/// Photographs a till receipt, reads it on the device and opens the expense
/// sheet filled in from it: the store, the total, the date, the lines in the
/// notes and the photo attached. When the receipt lists things the household
/// already buys, the sheet offers to record them as bought, which happens
/// once the expense is saved. Everything stays editable; returns what the
/// sheet returns.
Future<bool?> scanReceiptToExpense(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final groupId = ref.read(currentGroupIdProvider);
  final photo = await captureDocumentPhoto(
    context,
    ref,
    title: l10n.receiptScanTitle,
    readingMessage: l10n.receiptScanReading,
    interpret: (lines) async {
      final reading = const ReceiptParser().parse(
        lines,
        now: now,
        // Slashed dates are ambiguous; the device's region says which way.
        monthFirst:
            WidgetsBinding.instance.platformDispatcher.locale.countryCode ==
                'US',
      );
      return (
        reading: reading,
        purchases: groupId == null
            ? const <ReceiptPurchase>[]
            : await _householdPurchases(ref, reading, groupId),
      );
    },
  );
  if (photo == null || !context.mounted) return null;
  final (:reading, :purchases) = photo.result;

  final amount = reading.amountCents;
  if (amount == null) {
    AppToast.info(context, l10n.receiptScanNoTotal);
  } else if (reading.items.isNotEmpty && !reading.itemsMatchTotal) {
    AppToast.info(context, l10n.receiptScanCheckTotal);
  }
  final date = receiptExpenseDate(reading.date, now: now);

  final prefs = await SharedPreferences.getInstance();
  final remember =
      ValueNotifier(prefs.getBool(kRememberReceiptPurchasesPref) ?? true);
  try {
    if (!context.mounted) return null;
    final saved = await ExpenseCreationSheet.show(
      context,
      initialDescription: reading.store,
      initialAmount: amount == null || amount <= 0
          ? null
          : (amount / 100).toStringAsFixed(2),
      initialDate: date,
      initialNotes: receiptNotes(reading),
      receiptImage: File(photo.capture.originalPath),
      receiptPurchaseCount: purchases.length,
      rememberReceiptPurchases: remember,
    );
    if (saved == true && groupId != null && purchases.isNotEmpty) {
      await prefs.setBool(kRememberReceiptPurchasesPref, remember.value);
      if (remember.value) {
        await _recordPurchases(
          ref,
          groupId,
          purchases,
          receiptPurchaseTime(date, now: now),
        );
      }
    }
    return saved;
  } finally {
    remember.dispose();
  }
}

/// The receipt's date when it is a plausible "when this happened": not in
/// the future and within [kReceiptDateWindow].
@visibleForTesting
DateTime? receiptExpenseDate(DateTime? date, {required DateTime now}) =>
    date != null &&
            !date.isAfter(now) &&
            now.difference(date) <= kReceiptDateWindow
        ? date
        : null;

/// When the receipt's items were bought: now for today's receipt (or one
/// without a date), midday of the printed day otherwise.
@visibleForTesting
DateTime receiptPurchaseTime(DateTime? date, {required DateTime now}) {
  if (date == null ||
      (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day)) {
    return now;
  }
  return DateTime(date.year, date.month, date.day, 12);
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

Future<List<ReceiptPurchase>> _householdPurchases(
  WidgetRef ref,
  ReceiptReading reading,
  String groupId,
) async {
  try {
    // The grocery catalog must be in place before anything can be linked.
    await ref.read(grocerySeedProvider.future);
    return await ReceiptPurchaseMatcher(
      ref.read(appDatabaseProvider),
      ref.read(canonicalLinkServiceProvider),
    ).match(reading, groupId);
  } catch (error, stack) {
    // The expense still works without them.
    ErrorReporter().captureException(error, stackTrace: stack);
    return const [];
  }
}

Future<void> _recordPurchases(
  WidgetRef ref,
  String groupId,
  List<ReceiptPurchase> purchases,
  DateTime purchasedAt,
) async {
  try {
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.recordReceiptPurchases(
      groupId: groupId,
      purchases: purchases,
      purchasedAt: purchasedAt,
    );
  } catch (error, stack) {
    // The expense is saved; a missed purchase signal must not undo that.
    ErrorReporter().captureException(error, stackTrace: stack);
  }
}
