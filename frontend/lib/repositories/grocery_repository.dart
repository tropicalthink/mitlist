import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../utils/uuid_validation.dart';
import '../services/api_client.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';

/// Syncs the grocery graph with the backend and handles SSE invalidation.
///
/// Pull strategy: the client stores a per-group `version` cursor in Drift's
/// `grocery_versions` table. On each sync it calls
/// `GET /groups/{id}/grocery/graph?since_version=N` and upserts the delta.
class GroceryRepository {
  final AppDatabase _db;
  final Dio _dio;
  final Logger _log = Logger();

  SseService? _sseService;
  StreamSubscription<SseEvent>? _sseSub;
  String? _sseGroupId;

  GroceryRepository({required AppDatabase db, required Dio dio})
      : _db = db,
        _dio = dio;

  static Future<GroceryRepository> create(AppDatabase db, [Ref? ref]) async {
    final dio = resolveDio(ref);
    return GroceryRepository(db: db, dio: dio);
  }

  // ---------------------------------------------------------------------------
  // SSE attachment
  // ---------------------------------------------------------------------------

  void attachSse(SseService sseService, String groupId) {
    if (_sseService == sseService && _sseGroupId == groupId) return;
    _sseSub?.cancel();
    _sseService = sseService;
    _sseGroupId = groupId;
    sseService.connect(groupId);
    _sseSub = sseService.events.listen(_handleSseEvent);
  }

  void detachSse() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseService = null;
    _sseGroupId = null;
  }

  Future<void> _handleSseEvent(SseEvent event) async {
    if (_sseGroupId == null) return;
    if (event.type == 'grocery:graph_updated') {
      await pullDelta(_sseGroupId!);
    }
  }

  // ---------------------------------------------------------------------------
  // Delta sync
  // ---------------------------------------------------------------------------

  /// Pull and apply all graph rows newer than the stored cursor.
  Future<void> pullDelta(String groupId) async {
    try {
      const maxPages = 20;
      for (var page = 0; page < maxPages; page++) {
        final sinceVersion = await _db.getGroceryVersion(groupId);
        final r = await _dio.get(
          '/groups/$groupId/grocery/graph',
          queryParameters: {'since_version': sinceVersion},
        );
        final data = r.data as Map<String, dynamic>;
        await _applyDelta(groupId, data);
        if (data['has_more'] != true) return;
      }
      _log.w('Grocery graph pull stopped after max page limit');
    } on DioException catch (e) {
      _log.w('Grocery graph pull failed: ${e.response?.statusCode}');
    } catch (e) {
      _log.w('Grocery graph pull error: $e');
    }
  }

  @visibleForTesting
  Future<void> applyDeltaForTesting(
    String groupId,
    Map<String, dynamic> delta,
  ) =>
      _applyDelta(groupId, delta);

  Future<void> _applyDelta(String groupId, Map<String, dynamic> delta) async {
    final maxVersion = (delta['max_version'] as num?)?.toInt() ?? 0;
    if (maxVersion == 0) return;

    final now = DateTime.now();
    final localItems = [
      ...await _db.getCanonicalItemsByGroup('__global__'),
      ...await _db.getCanonicalItemsByGroup(groupId),
    ];
    final reverse = {for (final it in localItems) apiCanonicalId(it.id): it.id};
    String mapId(String id) => reverse[id] ?? id;

    // Canonical items.
    final rawItems = delta['canonical_items'] as List? ?? [];
    if (rawItems.isNotEmpty) {
      final items = rawItems.cast<Map<String, dynamic>>().where((j) {
        return !reverse.containsKey(j['id'] as String);
      }).map((j) {
        final createdAt = _parseDate(j['created_at']) ?? now;
        final updatedAt = _parseDate(j['updated_at']) ?? now;
        return CanonicalItemsTableCompanion.insert(
          id: j['id'] as String,
          groupId: j['group_id'] as String,
          nameDe: Value(j['name_de'] as String? ?? ''),
          nameEn: Value(j['name_en'] as String? ?? ''),
          category: Value(j['category'] as String? ?? ''),
          defaultUnit: Value(j['default_unit'] as String? ?? ''),
          isGlobal: Value(j['is_global'] as bool? ?? false),
          version: Value(j['version'] as int? ?? 0),
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: Value(_parseDate(j['deleted_at'])),
        );
      }).toList();
      await _db.upsertCanonicalItems(items);
    }

    // Item aliases.
    final rawAliases = delta['item_aliases'] as List? ?? [];
    if (rawAliases.isNotEmpty) {
      final aliases = rawAliases.cast<Map<String, dynamic>>().map((j) {
        final createdAt = _parseDate(j['created_at']) ?? now;
        final updatedAt = _parseDate(j['updated_at']) ?? now;
        return ItemAliasesTableCompanion.insert(
          id: j['id'] as String,
          groupId: j['group_id'] as String,
          canonicalItemId: mapId(j['canonical_item_id'] as String),
          aliasText: j['alias_text'] as String,
          lang: Value(j['lang'] as String? ?? 'de'),
          source: Value(j['source'] as String? ?? 'seed'),
          weight: Value(j['weight'] as int? ?? 1),
          version: Value(j['version'] as int? ?? 0),
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: Value(_parseDate(j['deleted_at'])),
        );
      }).toList();
      await _db.upsertItemAliases(aliases);
    }

    // Corrections.
    final rawCorrections = delta['corrections'] as List? ?? [];
    if (rawCorrections.isNotEmpty) {
      final corrections = rawCorrections.cast<Map<String, dynamic>>().map((j) {
        final createdAt = _parseDate(j['created_at']) ?? now;
        return CorrectionsTableCompanion.insert(
          id: j['id'] as String,
          groupId: j['group_id'] as String,
          kind: j['kind'] as String? ?? 'alias',
          userId: Value(j['user_id'] as String?),
          scope: Value(j['scope'] as String? ?? 'household'),
          rawText: Value(j['raw_text'] as String? ?? ''),
          resolvedCanonicalItemId: Value(
            j['resolved_canonical_item_id'] == null
                ? null
                : mapId(j['resolved_canonical_item_id'] as String),
          ),
          correctedValueJson: Value(
            j['corrected_value'] != null
                ? jsonEncode(j['corrected_value'])
                : null,
          ),
          source: Value(j['source'] as String? ?? 'client'),
          version: Value(j['version'] as int? ?? 0),
          createdAt: createdAt,
          appliedAt: Value(_parseDate(j['applied_at'])),
        );
      }).toList();
      await _db.upsertCorrections(corrections);
    }

    // Store aisles.
    final rawAisles = delta['store_aisles'] as List? ?? [];
    if (rawAisles.isNotEmpty) {
      final aisles = rawAisles.cast<Map<String, dynamic>>().map((j) {
        final createdAt = _parseDate(j['created_at']) ?? now;
        final updatedAt = _parseDate(j['updated_at']) ?? now;
        return StoreAislesTableCompanion.insert(
          id: j['id'] as String,
          groupId: j['group_id'] as String,
          canonicalItemId: mapId(j['canonical_item_id'] as String),
          storeId: Value(j['store_id'] as String?),
          aisle: Value(j['aisle'] as String? ?? ''),
          sortOrder: Value(j['sort_order'] as int? ?? 99),
          confidence: Value((j['confidence'] as num?)?.toDouble() ?? 1.0),
          version: Value(j['version'] as int? ?? 0),
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: Value(_parseDate(j['deleted_at'])),
        );
      }).toList();
      await _db.upsertStoreAisles(aisles);
    }

    final rawPurchases = delta['purchase_history'] as List? ?? [];
    if (rawPurchases.isNotEmpty) {
      final purchases = rawPurchases.cast<Map<String, dynamic>>().map((j) {
        final rawCanonicalId = j['canonical_item_id'] as String?;
        return PurchaseHistoryTableCompanion.insert(
          id: j['id'] as String,
          groupId: groupId,
          canonicalItemId: Value(
            rawCanonicalId == null ? null : mapId(rawCanonicalId),
          ),
          listItemId: Value(j['list_item_id'] as String?),
          quantity: Value((j['quantity'] as num?)?.toDouble() ?? 1),
          unit: Value(j['unit'] as String? ?? ''),
          version: Value((j['version'] as num?)?.toInt() ?? 0),
          purchasedAt: _parseDate(j['purchased_at']) ?? now,
        );
      });
      await _db.upsertPurchaseHistory(purchases);
    }

    final rawCooccurrences = delta['item_cooccurrence'] as List? ?? [];
    if (rawCooccurrences.isNotEmpty) {
      final cooccurrences =
          rawCooccurrences.cast<Map<String, dynamic>>().map((j) {
        return ItemCooccurrenceTableCompanion.insert(
          groupId: groupId,
          itemAId: mapId(j['item_a_id'] as String),
          itemBId: mapId(j['item_b_id'] as String),
          count: Value((j['count'] as num?)?.toInt() ?? 0),
          lastSeenAt: _parseDate(j['last_seen_at']) ?? now,
          version: Value((j['version'] as num?)?.toInt() ?? 0),
        );
      });
      await _db.upsertCooccurrence(cooccurrences);
    }

    await _db.setGroceryVersion(groupId, maxVersion);
    _log.d('Grocery graph applied delta maxVersion=$maxVersion');
  }

  // ---------------------------------------------------------------------------
  // Aisle feedback upload (Phase 5)
  // ---------------------------------------------------------------------------

  /// Persists aisle drag-to-reorder feedback from the review screen.
  /// Writes locally first via [db.upsertStoreAisles], then uploads to server.
  Future<void> updateAisleFeedback({
    required String groupId,
    required List<AisleFeedbackEntry> entries,
  }) async {
    if (entries.isEmpty) return;

    final now = DateTime.now();
    // Local write first — stays in sync even if upload fails.
    final companions = entries.map((e) => StoreAislesTableCompanion.insert(
          id: e.id,
          groupId: groupId,
          canonicalItemId: e.canonicalItemId,
          storeId: Value(e.storeId),
          aisle: Value(e.aisle),
          sortOrder: Value(e.sortOrder),
          confidence: const Value(1.0),
          version: const Value(0),
          createdAt: now,
          updatedAt: now,
        ));
    await _db.upsertStoreAisles(companions);

    // Best-effort server upload.
    try {
      await _dio.patch(
        '/groups/$groupId/grocery/aisles',
        data: {
          'aisles': entries
              .map((e) => {
                    'canonical_item_id': apiCanonicalId(e.canonicalItemId),
                    // Seed store slugs are local-only; the API accepts UUID stores.
                    if (isApiUuid(e.storeId)) 'store_id': e.storeId,
                    'aisle': e.aisle,
                    'sort_order': e.sortOrder,
                  })
              .toList(),
        },
      );
    } on DioException catch (e) {
      _log.w('Aisle feedback upload failed: ${e.response?.statusCode}');
    } catch (e) {
      _log.w('Aisle feedback upload error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Correction upload
  // ---------------------------------------------------------------------------

  /// Upload a confirmed alias correction. Returns the new server version or 0
  /// on failure (offline / error is silently swallowed — the local alias row
  /// was already written by [CorrectionMemoryService]).
  Future<int> uploadCorrection({
    required String groupId,
    required String rawText,
    required String canonicalItemId,
    String kind = 'alias',
    String scope = 'household',
    String lang = 'de',
  }) async {
    final apiId = apiCanonicalId(canonicalItemId);
    final canonicalItem = await _db.getCanonicalItemById(canonicalItemId);
    if (canonicalItem == null) return 0;

    try {
      final r = await _dio.post(
        '/groups/$groupId/grocery/corrections',
        data: {
          'raw_text': rawText,
          'kind': kind,
          'scope': scope,
          'canonical_item_id': apiId,
          'canonical_item': {
            'id': apiId,
            'name_de': canonicalItem.nameDe,
            'name_en': canonicalItem.nameEn,
            'category': canonicalItem.category,
            'default_unit': canonicalItem.defaultUnit,
          },
          'lang': lang,
        },
      );
      return (r.data['version'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      _log.w('Correction upload failed: ${e.response?.statusCode}');
      return 0;
    } catch (e) {
      _log.w('Correction upload error: $e');
      return 0;
    }
  }

  Future<int> uploadReject({
    required String groupId,
    required String rawText,
  }) async {
    try {
      final r = await _dio.post(
        '/groups/$groupId/grocery/corrections',
        data: {'raw_text': rawText, 'kind': 'reject', 'scope': 'household'},
      );
      return (r.data['version'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      _log.w('Reject upload failed: ${e.response?.statusCode}');
      return 0;
    } catch (e) {
      _log.w('Reject upload error: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw as String);
    } catch (_) {
      return null;
    }
  }
}

/// Value object carrying a single drag-to-reorder aisle feedback event.
class AisleFeedbackEntry {
  final String id;
  final String canonicalItemId;
  final String? storeId;
  final String aisle;
  final int sortOrder;

  const AisleFeedbackEntry({
    required this.id,
    required this.canonicalItemId,
    this.storeId,
    required this.aisle,
    required this.sortOrder,
  });
}
