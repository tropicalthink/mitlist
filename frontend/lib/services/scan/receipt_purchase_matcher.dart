import '../../storage/app_database.dart';
import 'canonical_link_service.dart';
import 'receipt_parser.dart';

/// A receipt line recognised as one of the household's own grocery items.
class ReceiptPurchase {
  const ReceiptPurchase({
    required this.canonicalItemId,
    required this.name,
    this.quantity = 1,
  });

  final String canonicalItemId;

  /// The first receipt line it was read from ("ORANGE NET").
  final String name;

  /// How many lines of the receipt it was ("Traubendirektsaft" three times).
  final double quantity;
}

/// An open item on one of the household's shopping lists that a receipt
/// shows was bought.
class ReceiptListItem {
  const ReceiptListItem({
    required this.listId,
    required this.itemId,
    required this.name,
    required this.canonicalItemId,
  });

  final String listId;
  final String itemId;

  /// The item's name on the list ("Milk"), not the receipt's.
  final String name;
  final String canonicalItemId;
}

/// Finds which lines of a receipt are things the household already buys.
///
/// Receipt text is shorthand ("TUNA STEAKS", "ORANGE NET", "C/CHP COOKIE"),
/// and the catalog alone links some of it confidently to the wrong product
/// (Tuna Salad, Orange Zest). A purchase recorded from it would then teach
/// restock and suggestions about things the household never buys. So a line
/// counts only when the household-aware resolver links it confidently *and*
/// the item is one the household already keeps track of: a receipt confirms
/// purchases, it does not introduce new items. Everything else on the
/// receipt is still kept in the expense notes.
class ReceiptPurchaseMatcher {
  ReceiptPurchaseMatcher(this._db, this._linker);

  final AppDatabase _db;
  final CanonicalLinkService _linker;

  Future<List<ReceiptPurchase>> match(
    ReceiptReading reading,
    String groupId,
  ) async {
    final products = [
      for (final item in reading.items)
        if (!item.isAdjustment && item.amountCents > 0) item,
    ];
    if (products.isEmpty) return const [];
    final known = await _db.getHouseholdCanonicalIds(groupId);
    if (known.isEmpty) return const [];

    final context = await _linker.prepareContext(groupId);
    final names = <String, String>{};
    final counts = <String, double>{};
    for (final item in products) {
      final id = await _linker.resolveHighConfidence(
        item.name,
        groupId,
        context: context,
      );
      if (id == null || !known.contains(id)) continue;
      names.putIfAbsent(id, () => item.name);
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return [
      for (final entry in names.entries)
        ReceiptPurchase(
          canonicalItemId: entry.key,
          name: entry.value,
          quantity: counts[entry.key]!,
        ),
    ];
  }

  /// The open shopping-list items [purchases] account for: an item counts
  /// when it is linked to the same grocery item as a receipt line, which is
  /// the household's own vocabulary agreeing with the receipt, so names alone
  /// ("Milk" against "MILK ROLL") never tick anything. One line ticks one
  /// item; when a thing is on several lists, the list the receipt covers
  /// most wins (the one that was being shopped), then the most recent one.
  /// An item added after [boughtBy] cannot have been on this receipt.
  Future<List<ReceiptListItem>> openListItems(
    List<ReceiptPurchase> purchases,
    String groupId, {
    required DateTime boughtBy,
  }) async {
    if (purchases.isEmpty) return const [];
    final wanted = {for (final p in purchases) p.canonicalItemId: p.quantity};
    final lists = [
      for (final list in await _db.getListsByGroupOnce(groupId))
        if (list.type == 'shopping') list,
    ];
    final candidates = <(ListsTableData, ListItemsTableData)>[];
    for (final list in lists) {
      for (final item in await _db.getItemsByListOnce(list.id)) {
        if (item.checked || item.createdAt.isAfter(boughtBy)) continue;
        if (!wanted.containsKey(item.canonicalItemId)) continue;
        candidates.add((list, item));
      }
    }
    if (candidates.isEmpty) return const [];

    final coverage = <String, int>{};
    for (final (list, _) in candidates) {
      coverage[list.id] = (coverage[list.id] ?? 0) + 1;
    }
    candidates.sort((a, b) {
      final byCoverage = coverage[b.$1.id]!.compareTo(coverage[a.$1.id]!);
      if (byCoverage != 0) return byCoverage;
      final byRecency = b.$1.updatedAt.compareTo(a.$1.updatedAt);
      if (byRecency != 0) return byRecency;
      return a.$2.position.compareTo(b.$2.position);
    });
    final left = {
      for (final entry in wanted.entries) entry.key: entry.value.ceil(),
    };
    return [
      for (final (list, item) in candidates)
        if (_take(left, item.canonicalItemId!))
          ReceiptListItem(
            listId: list.id,
            itemId: item.id,
            name: item.name,
            canonicalItemId: item.canonicalItemId!,
          ),
    ];
  }

  static bool _take(Map<String, int> left, String id) {
    final n = left[id] ?? 0;
    if (n <= 0) return false;
    left[id] = n - 1;
    return true;
  }
}
