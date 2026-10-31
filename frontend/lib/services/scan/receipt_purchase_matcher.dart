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
}
