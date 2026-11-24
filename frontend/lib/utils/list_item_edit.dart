import '../models/list_models.dart';
import 'list_composer_parser.dart';

/// "2", "1.5", "0.25": an amount as a person writes it, without trailing
/// zeros.
String formatItemAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// "3.00" for 300 cents; empty for no price.
String formatPriceInput(int? cents) =>
    cents != null && cents > 0 ? (cents / 100).toStringAsFixed(2) : '';

/// An amount typed as "2", "1.5" or "1,5"; null when it is not a positive
/// number.
double? parseItemAmount(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || value <= 0 || value.isNaN || value.isInfinite) {
    return null;
  }
  return value;
}

/// A price typed as "3", "3.5" or "3,50", in cents. An empty field is 0,
/// which clears the price; null means the text is not a price.
int? parsePriceCents(String text) {
  final cleaned = text.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return 0;
  final value = double.tryParse(cleaned);
  if (value == null || value < 0 || value.isNaN || value.isInfinite) {
    return null;
  }
  return (value * 100).round();
}

/// What one edit of a list line changed, field by field, as
/// `ListDetailController.updateItemFields` takes it: null is "unchanged",
/// a [priceCents] of 0 clears the price and an empty [unit] or [note] clears
/// that field.
class ListItemEdit {
  const ListItemEdit({
    this.name,
    this.quantity,
    this.unit,
    this.note,
    this.priceCents,
    this.priceUnreadable = false,
  });

  final String? name;
  final double? quantity;
  final String? unit;
  final String? note;
  final int? priceCents;

  /// The price field held something that is not a price; it was left as it
  /// was rather than guessed at.
  final bool priceUnreadable;

  bool get hasChanges =>
      name != null ||
      quantity != null ||
      unit != null ||
      note != null ||
      priceCents != null;

  /// Compares the fields as the person left them with [original], the item
  /// as it was when editing began. An amount written into a changed name
  /// ("2 kg flour") is read the way the add line reads it and wins over the
  /// amount and unit fields. An empty [name] is not a change here: the
  /// caller deletes the item instead.
  static ListItemEdit diff(
    ListItem original, {
    required String name,
    required String amount,
    required String unit,
    required String note,
    required String price,
  }) {
    var nextName = name.trim();
    var nextAmount = parseItemAmount(amount);
    var nextUnit = unit.trim();
    if (nextName != original.name.trim()) {
      final parsed = parseComposerItem(nextName);
      if (parsed.name != nextName) {
        nextName = parsed.name;
        nextAmount = parsed.quantity;
        if (parsed.unit.isNotEmpty) nextUnit = parsed.unit;
      }
    }
    final nextNote = note.trim();
    final nextPrice = parsePriceCents(price);
    final oldPrice = original.priceCents ?? 0;
    // The amount field showed the quantity rounded to two places: reading
    // that back unchanged is no edit, and must not overwrite 0.333 with 0.33.
    final shownAmount = parseItemAmount(formatItemAmount(original.quantity));
    return ListItemEdit(
      name: nextName.isNotEmpty && nextName != original.name.trim()
          ? nextName
          : null,
      quantity: nextAmount != null &&
              nextAmount != original.quantity &&
              nextAmount != shownAmount
          ? nextAmount
          : null,
      unit: nextUnit != original.unit ? nextUnit : null,
      note: nextNote != original.note ? nextNote : null,
      priceCents: nextPrice != null && nextPrice != oldPrice ? nextPrice : null,
      priceUnreadable: nextPrice == null,
    );
  }
}
