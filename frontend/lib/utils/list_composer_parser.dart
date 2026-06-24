/// The result of parsing a quick-add composer string such as `"2 kg flour"`
/// into a structured name / quantity / unit.
class ParsedComposerItem {
  const ParsedComposerItem({
    required this.name,
    this.quantity = 1,
    this.unit = '',
  });

  final String name;
  final double quantity;
  final String unit;
}

/// Parses a free-text composer entry into [ParsedComposerItem].
///
/// Rules (kept deliberately forgiving):
/// - A leading numeric token is treated as a quantity (`"2 milk"` → 2 × milk).
///   Comma decimals are accepted (`"1,5 l water"`).
/// - If a short, non-numeric token follows the quantity, it's treated as a unit
///   (`"2 kg flour"` → 2 kg × flour). Units longer than 12 chars are ignored.
/// - Anything that doesn't fit (no quantity, non-positive quantity, empty name)
///   falls back to the whole trimmed string as the item name with quantity 1.
ParsedComposerItem parseComposerItem(String text) {
  final parts = text.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return ParsedComposerItem(name: text.trim());
  final quantity = double.tryParse(parts.first.replaceAll(',', '.'));
  if (quantity == null || quantity <= 0) {
    return ParsedComposerItem(name: text.trim());
  }
  var unit = '';
  var nameStart = 1;
  if (parts.length >= 3 &&
      parts[1].length <= 12 &&
      !RegExp(r'\d').hasMatch(parts[1])) {
    unit = parts[1];
    nameStart = 2;
  }
  final name = parts.skip(nameStart).join(' ').trim();
  if (name.isEmpty) return ParsedComposerItem(name: text.trim());
  return ParsedComposerItem(name: name, quantity: quantity, unit: unit);
}
