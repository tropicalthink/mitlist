import 'package:uuid/uuid.dart';

import '../../storage/app_database.dart';
import 'resolution/string_sim.dart';
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
    final normalised = normaliseText(rawText);
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
      // Never reuse a global seed row's id: overwriting it would destroy the
      // shipped mapping (and the alias collision the ensemble scores against).
      // A household correction gets its own row; findAlias prefers it via
      // weight ordering.
      final reuseId = (existing != null && existing.groupId == groupId)
          ? existing.id
          : null;
      await _db.upsertItemAliases([
        ItemAliasesTableCompanion.insert(
          id: reuseId ?? _uuid.v4(),
          groupId: groupId,
          canonicalItemId: canonicalItemId,
          aliasText: normalised,
          lang: const Value('und'),
          source: const Value('correction'),
          weight: Value((existing?.weight ?? 0) + 1),
          version: const Value(0),
          createdAt: reuseId != null ? existing!.createdAt : now,
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
    String? rejectedCanonicalItemId,
  }) async {
    await _db.insertCorrection(CorrectionsTableCompanion.insert(
      id: _uuid.v4(),
      groupId: groupId,
      userId: Value(userId),
      scope: const Value('household'),
      kind: 'reject',
      rawText: Value(normaliseText(rawText)),
      resolvedCanonicalItemId: Value(rejectedCanonicalItemId),
      version: const Value(0),
      createdAt: DateTime.now(),
    ));
  }
}
