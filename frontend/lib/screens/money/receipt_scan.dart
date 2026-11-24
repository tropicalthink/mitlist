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

/// Whether the last receipt ticked off what it covered on the lists.
const String kTickReceiptListItemsPref = 'receipt_tick_list_items';

/// Photographs a till receipt, reads it on the device and opens the expense
/// sheet filled in from it: the store, the total, the date, the lines in the
/// notes and the photo attached. When the receipt lists things the household
/// already buys, the sheet offers to record them as bought, and to tick off
/// the open shopping-list items they account for; both happen once the
/// expense is saved. Everything stays editable; returns what the sheet
/// returns.
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
      if (groupId == null) {
        return (
          reading: reading,
          purchases: const <ReceiptPurchase>[],
          listItems: const <ReceiptListItem>[],
        );
      }
      final (purchases, listItems) = await _householdMatches(
        ref,
        reading,
        groupId,
        boughtBy: receiptBoughtBy(
          receiptExpenseDate(reading.date, now: now),
          now: now,
        ),
      );
      return (reading: reading, purchases: purchases, listItems: listItems);
    },
  );
  if (photo == null || !context.mounted) return null;
  final (:reading, :purchases, :listItems) = photo.result;

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
  final tick = ValueNotifier(prefs.getBool(kTickReceiptListItemsPref) ?? true);
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
      receiptListItemNames: [for (final item in listItems) item.name],
      tickReceiptListItems: tick,
    );
    if (saved == true && groupId != null && purchases.isNotEmpty) {
      await prefs.setBool(kRememberReceiptPurchasesPref, remember.value);
      if (listItems.isNotEmpty) {
        await prefs.setBool(kTickReceiptListItemsPref, tick.value);
      }
      await _applyReceipt(
        ref,
        groupId,
        purchases: remember.value ? purchases : const [],
        listItems: tick.value ? listItems : const [],
        purchasedAt: receiptPurchaseTime(date, now: now),
      );
    }
    return saved;
  } finally {
    remember.dispose();
    tick.dispose();
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

/// The latest moment the receipt's shopping can have happened: now for
/// today's receipt (or one without a date), the end of the printed day
/// otherwise. A list item added after it was not on that receipt.
@visibleForTesting
DateTime receiptBoughtBy(DateTime? date, {required DateTime now}) {
  if (date == null) return now;
  final endOfDay = DateTime(date.year, date.month, date.day + 1);
  return endOfDay.isAfter(now) ? now : endOfDay;
}

/// What is left to record as purchases once [ticked] list items are checked
/// off: a check-off already records its own purchase, so the same thing is
/// not counted twice when the receipt is older than the recheck window.
@visibleForTesting
List<ReceiptPurchase> purchasesBesides(
  List<ReceiptPurchase> purchases,
  List<ReceiptListItem> ticked,
) {
  final covered = {for (final item in ticked) item.canonicalItemId};
  return [
    for (final purchase in purchases)
      if (!covered.contains(purchase.canonicalItemId)) purchase,
  ];
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

Future<(List<ReceiptPurchase>, List<ReceiptListItem>)> _householdMatches(
  WidgetRef ref,
  ReceiptReading reading,
  String groupId, {
  required DateTime boughtBy,
}) async {
  try {
    // The grocery catalog must be in place before anything can be linked.
    await ref.read(grocerySeedProvider.future);
    final matcher = ReceiptPurchaseMatcher(
      ref.read(appDatabaseProvider),
      ref.read(canonicalLinkServiceProvider),
    );
    final purchases = await matcher.match(reading, groupId);
    final listItems = await matcher.openListItems(
      purchases,
      groupId,
      boughtBy: boughtBy,
    );
    return (purchases, listItems);
  } catch (error, stack) {
    // The expense still works without them.
    ErrorReporter().captureException(error, stackTrace: stack);
    return (const <ReceiptPurchase>[], const <ReceiptListItem>[]);
  }
}

Future<void> _applyReceipt(
  WidgetRef ref,
  String groupId, {
  required List<ReceiptPurchase> purchases,
  required List<ReceiptListItem> listItems,
  required DateTime purchasedAt,
}) async {
  try {
    final repo = await ref.read(listRepositoryProvider.future);
    // Ticked first, so the receipt's purchases see them as the same trip.
    if (listItems.isNotEmpty) {
      final byList = <String, List<String>>{};
      for (final item in listItems) {
        (byList[item.listId] ??= []).add(item.itemId);
      }
      await repo.completeItemsOfflineFirst(byList);
    }
    final rest = purchasesBesides(purchases, listItems);
    if (rest.isNotEmpty) {
      await repo.recordReceiptPurchases(
        groupId: groupId,
        purchases: rest,
        purchasedAt: purchasedAt,
      );
    }
  } catch (error, stack) {
    // The expense is saved; a missed check-off or purchase signal must not
    // undo that.
    ErrorReporter().captureException(error, stackTrace: stack);
  }
}
