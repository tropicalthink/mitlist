import 'uuid_validation.dart';

/// What a link from outside the app asks for besides its route (plans/047,
/// contract C5). Home screen widgets, Controls, Siri and app icon shortcuts
/// open `mitlist:///…` links that may carry:
/// - `group=<household id>`: switch to that household first, so the screen
///   shows the household the widget belongs to;
/// - on `/money`, `add=1` and optionally `amount_cents=<n>`: open the
///   expense sheet, prefilled (the shopping-trip Live Activity's "Add
///   expense").
///
/// `add=1` on `/lists/<id>` is left in place: the list route reads it to
/// focus the composer.
class AppLinkIntent {
  const AppLinkIntent({
    required this.location,
    this.groupId,
    this.openExpenseSheet = false,
    this.amountCents,
  });

  /// The location with the consumed parameters removed.
  final String location;
  final String? groupId;
  final bool openExpenseSheet;
  final int? amountCents;

  /// The amount as the expense sheet's text field expects it ("12.34").
  String? get initialAmount =>
      amountCents == null ? null : (amountCents! / 100).toStringAsFixed(2);

  /// Null when [uri] carries nothing to act on.
  static AppLinkIntent? parse(Uri uri) {
    final query = Map<String, String>.of(uri.queryParameters);
    final rawGroup = query.remove('group');
    final groupId = rawGroup != null && isApiUuid(rawGroup) ? rawGroup : null;

    var openExpenseSheet = false;
    int? amountCents;
    if (uri.path == '/money' && query['add'] == '1') {
      query.remove('add');
      openExpenseSheet = true;
      final cents = int.tryParse(query.remove('amount_cents') ?? '');
      if (cents != null && cents > 0) amountCents = cents;
    }
    if (rawGroup == null && !openExpenseSheet) return null;

    final cleaned = Uri(
      path: uri.path,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
    return AppLinkIntent(
      location: cleaned,
      groupId: groupId,
      openExpenseSheet: openExpenseSheet,
      amountCents: amountCents,
    );
  }
}

/// An expense sheet a link asked to open, waiting for the money screen.
class PendingExpenseDraft {
  const PendingExpenseDraft({this.initialAmount});
  final String? initialAmount;
}
