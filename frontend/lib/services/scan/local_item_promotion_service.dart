import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../storage/app_database.dart';
import 'correction_memory_service.dart';
import 'resolution/string_sim.dart';

/// How many times a household must check off an *unresolved* word before it is
/// promoted into a household-local canonical item (and therefore starts
/// appearing in autocomplete/suggestions and feeding the learning loop).
///
/// A word that resolves to a seed canonical (score >= 0.85) never touches this
/// path — it learns on the first check-off. This threshold only governs the
/// long tail: novel/misspelled/personal words the global brain doesn't know.
/// Kept low enough that a genuinely recurring buy surfaces quickly, high enough
/// that a one-off typo doesn't mint a canonical.
const int kLocalPromotionThreshold = 3;

/// Outcome of recording one unresolved check-off.
class LocalPromotionResult {
  /// The household-local canonical id the word now maps to.
  final String canonicalItemId;

  /// The normalised form the signal/alias is keyed by (what the caller should
  /// pass to a cross-device correction upload as `rawText`).
  final String normalizedName;

  /// True only on the check-off that crossed the threshold and minted the
  /// canonical — the caller uses this to fire a one-time cross-device sync.
  final bool justPromoted;

  const LocalPromotionResult({
    required this.canonicalItemId,
    required this.normalizedName,
    required this.justPromoted,
  });
}

/// Turns repeatedly-bought-but-unresolved grocery words into household-local
/// canonical items.
///
/// The read/write machinery for suggestions (alias autocomplete, purchase
/// history, co-occurrence, restock) is entirely keyed on `canonicalItemId` and
/// already household-`group_id`-scoped. So the whole fix is: count unresolved
/// check-offs off-device, and once a word crosses [kLocalPromotionThreshold],
/// mint a group-scoped canonical + alias for it. Everything downstream then
/// lights up unchanged, for that household only.
class LocalItemPromotionService {
  final AppDatabase _db;
  final CorrectionMemoryService _corrections;
  final Uuid _uuid;

  LocalItemPromotionService(
    AppDatabase db, {
    CorrectionMemoryService? corrections,
    Uuid? uuid,
  })  : _db = db,
        _corrections = corrections ?? CorrectionMemoryService(db),
        _uuid = uuid ?? const Uuid();

  /// Records one unresolved check-off of [rawName] for [groupId].
  ///
  /// Returns null while the word is still below the promotion threshold (the
  /// caller then learns nothing, exactly as before). Returns a
  /// [LocalPromotionResult] once the word has been promoted (on the crossing
  /// check-off and every check-off thereafter), so the caller can backfill the
  /// list item's canonical id and record the purchase signal normally.
  Future<LocalPromotionResult?> recordUnresolvedCheckoff({
    required String groupId,
    required String rawName,
    String userId = '',
  }) async {
    final normalized = normaliseText(rawName);
    if (normalized.isEmpty) return null;

    final now = DateTime.now();
    final existing = await _db.getLocalItemSignal(
      groupId: groupId,
      normalizedName: normalized,
    );
    final displayName = rawName.trim().isEmpty
        ? (existing?.displayName ?? normalized)
        : rawName.trim();

    // Already promoted — just keep the tally warm; the canonical + alias already
    // exist and surface. Frequency ranking is handled downstream by
    // purchase-history, so no alias re-weighting is needed here.
    final promotedId = existing?.promotedCanonicalItemId;
    if (promotedId != null) {
      await _writeSignal(
        groupId: groupId,
        normalized: normalized,
        displayName: displayName,
        count: existing!.count + 1,
        promotedCanonicalItemId: promotedId,
        firstSeen: existing.firstSeen,
        lastSeen: now,
      );
      return LocalPromotionResult(
        canonicalItemId: promotedId,
        normalizedName: normalized,
        justPromoted: false,
      );
    }

    final newCount = (existing?.count ?? 0) + 1;
    if (newCount < kLocalPromotionThreshold) {
      await _writeSignal(
        groupId: groupId,
        normalized: normalized,
        displayName: displayName,
        count: newCount,
        promotedCanonicalItemId: null,
        firstSeen: existing?.firstSeen ?? now,
        lastSeen: now,
      );
      return null;
    }

    // Threshold reached — mint a household-local canonical + alias.
    final canonicalId = _localCanonicalId(groupId, normalized);
    await _db.upsertCanonicalItems([
      CanonicalItemsTableCompanion.insert(
        id: canonicalId,
        groupId: groupId,
        // All locales point at the same display string so the suggestion UI
        // renders it whatever the user's locale.
        nameDe: Value(displayName),
        nameEn: Value(displayName),
        nameFr: Value(displayName),
        nameEs: Value(displayName),
        // isGlobal false keeps it out of the shared brain and makes
        // clearAllUserData reclaim it on logout.
        isGlobal: const Value(false),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    // Project the alias so autocomplete/prefix search finds it immediately.
    // recordAlias is idempotent and group-scoped; the 'local_promotion' source
    // tag distinguishes these from manual review corrections and from the seed.
    await _corrections.recordAlias(
      groupId: groupId,
      userId: userId,
      rawText: normalized,
      canonicalItemId: canonicalId,
      source: 'local_promotion',
    );

    await _writeSignal(
      groupId: groupId,
      normalized: normalized,
      displayName: displayName,
      count: newCount,
      promotedCanonicalItemId: canonicalId,
      firstSeen: existing?.firstSeen ?? now,
      lastSeen: now,
    );

    return LocalPromotionResult(
      canonicalItemId: canonicalId,
      normalizedName: normalized,
      justPromoted: true,
    );
  }

  Future<void> _writeSignal({
    required String groupId,
    required String normalized,
    required String displayName,
    required int count,
    required String? promotedCanonicalItemId,
    required DateTime firstSeen,
    required DateTime lastSeen,
  }) {
    return _db.upsertLocalItemSignal(LocalItemSignalsTableCompanion(
      groupId: Value(groupId),
      normalizedName: Value(normalized),
      displayName: Value(displayName),
      count: Value(count),
      promotedCanonicalItemId: Value(promotedCanonicalItemId),
      firstSeen: Value(firstSeen),
      lastSeen: Value(lastSeen),
    ));
  }

  /// Deterministic, household-unique canonical id for a promoted word. Derived
  /// from the group + normalised name so (a) a double-fire mints the same id
  /// (idempotent) and (b) two households that both buy "fassi" get *distinct*
  /// ids — required because the server upsert is `ON CONFLICT (id) DO NOTHING`
  /// and the first group to claim an id owns its group scope forever. The v5
  /// output is already a valid API UUID, so apiCanonicalId passes it through.
  String _localCanonicalId(String groupId, String normalized) =>
      _uuid.v5(Namespace.url.value, 'mitlist:hhcanonical:$groupId:$normalized');
}
