import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_link_intent.dart';

/// An expense sheet a link (`/money?add=1`) asked for. The router sets it;
/// the money screen opens the sheet and clears it.
final pendingExpenseDraftProvider =
    StateProvider<PendingExpenseDraft?>((ref) => null);
