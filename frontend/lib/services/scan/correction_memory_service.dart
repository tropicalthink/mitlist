import 'package:uuid/uuid.dart';

import '../../storage/app_database.dart';
import 'package:drift/drift.dart';

const _uuid = Uuid();

/// Reads and writes the unified correction event log.
///
/// Writing a correction:
///  1. Appends an immutable row to [correctionsTable] (the event log).
///  2. Immediately projects it into [itemAliasesTable] so the next scan's
///     exact-alias lookup picks it up without re-deriving anything.
class CorrectionMemoryService {
  final AppDatabase _db;

  CorrectionMemoryService(this._db);

  /// Record that [rawText] (normalised) should resolve to [canonicalItemId].
  /// Idempotent: if an alias already exists for this text/canonical pair, the
  /// weight is incremented instead.
  Future<void> recordAlias({
    required String groupId,
    required String userId,
    required String rawText,
    required String canonicalItemId,
    String source = 'manual_review',
  }) async {
    final normalised = rawText.toLowerCase().trim();
    if (normalised.isEmpty) return;

    final now = DateTime.now();

    // Append correction event (append-only).
    await _db.insertCorrection(CorrectionsTableCompanion.insert(
      id: _uuid.v4(),
      groupId: groupId,
      userId: Value(userId),
      scope: const Value('household'),
      kind: 'alias',
      rawText: Value(normalised),
      resolvedCanonicalItemId: Value(canonicalItemId),
      source: Value(source),
      version: const Value(0),
      createdAt: now,
      appliedAt: Value(now),
    ));

    // Project into fast-lookup alias table.
    final existing = await _db.findAlias(
      groupId: groupId,
      aliasText: normalised,
    );

    if (existing != null && existing.canonicalItemId == canonicalItemId) {
      // Reinforce existing alias.
      await _db.incrementAliasWeight(existing.id);
    } else {
      // Upsert with household scope (overrides any global seed).
      await _db.upsertItemAliases([
        ItemAliasesTableCompanion.insert(
          id: existing?.id ?? _uuid.v4(),
          groupId: groupId,
          canonicalItemId: canonicalItemId,
          aliasText: normalised,
          lang: const Value('und'),
          source: const Value('correction'),
          weight: Value((existing?.weight ?? 0) + 1),
          version: const Value(0),
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      ]);
    }
  }

  /// Record a "reject" correction: [rawText] should be ignored / not resolved.
  Future<void> recordReject({
    required String groupId,
    required String userId,
    required String rawText,
  }) async {
    await _db.insertCorrection(CorrectionsTableCompanion.insert(
      id: _uuid.v4(),
      groupId: groupId,
      userId: Value(userId),
      scope: const Value('household'),
      kind: 'reject',
      rawText: Value(rawText.toLowerCase().trim()),
      version: const Value(0),
      createdAt: DateTime.now(),
    ));
  }
}
