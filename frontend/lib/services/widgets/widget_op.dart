import 'dart:convert';

/// Delivery state of a queued widget op (plans/047, contract C2).
enum WidgetOpState { pending, delivered, failed }

/// One line of the native pending-ops queue: a change made on a home screen
/// widget, by Siri, a Control or the Android quick add, together with the
/// exact request that carries it to the server.
class WidgetOp {
  const WidgetOp({
    required this.opId,
    required this.type,
    required this.householdId,
    required this.method,
    required this.path,
    required this.body,
    required this.state,
    this.source,
    this.createdAt,
    this.listId,
    this.itemId,
    this.name,
    this.choreId,
    this.deliveredAt,
    this.response,
  });

  static const checkItem = 'list_item.check';
  static const addItem = 'list_item.add';
  static const completeChore = 'chore.complete';
  static const knownTypes = {checkItem, addItem, completeChore};

  final String opId;
  final String type;
  final String householdId;

  /// The exact request (method, path relative to the API base, body bytes).
  /// The app replays these verbatim: the server's idempotency check hashes
  /// them, so a re-serialised body would be rejected as a different request.
  final String method;
  final String path;
  final String body;

  final WidgetOpState state;
  final String? source;
  final DateTime? createdAt;
  final String? listId;
  final String? itemId;
  final String? name;
  final String? choreId;
  final DateTime? deliveredAt;

  /// The server's response body for a delivered op, when it was small enough
  /// to keep.
  final String? response;

  bool get isKnownType => knownTypes.contains(type);

  /// The response as a JSON object, or null.
  Map<String, dynamic>? get responseJson {
    final raw = response;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Parses one queue line. Null when it is not a usable op (malformed, or
  /// missing the request), which the importer skips.
  static WidgetOp? tryParse(String line) {
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    String? str(String key) {
      final value = decoded is Map<String, dynamic> ? decoded[key] : null;
      return value is String && value.isNotEmpty ? value : null;
    }

    final opId = str('op_id');
    final type = str('type');
    final householdId = str('household_id');
    final method = str('method');
    final path = str('path');
    final body = decoded['body'];
    if (opId == null ||
        type == null ||
        householdId == null ||
        method == null ||
        path == null ||
        !path.startsWith('/') ||
        body is! String) {
      return null;
    }
    final state = switch (str('state')) {
      'delivered' => WidgetOpState.delivered,
      'failed' => WidgetOpState.failed,
      _ => WidgetOpState.pending,
    };
    return WidgetOp(
      opId: opId,
      type: type,
      householdId: householdId,
      method: method.toUpperCase(),
      path: path,
      body: body,
      state: state,
      source: str('source'),
      createdAt: DateTime.tryParse(str('created_at') ?? ''),
      listId: str('list_id'),
      itemId: str('item_id'),
      name: str('name'),
      choreId: str('chore_id'),
      deliveredAt: DateTime.tryParse(str('delivered_at') ?? ''),
      response: str('response'),
    );
  }

  /// Best-effort op id of a line [tryParse] rejected, so a broken line can
  /// still be acknowledged and does not sit in the queue forever.
  static String? opIdOf(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map && decoded['op_id'] is String) {
        return decoded['op_id'] as String;
      }
    } catch (_) {}
    return null;
  }
}
