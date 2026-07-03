import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/correction_memory_service.dart';
import 'package:mitlist/services/scan/resolution/calibrated_scorer.dart';
import 'package:mitlist/services/scan/resolution/ensemble_resolver.dart';
import 'package:mitlist/storage/app_database.dart';

AppDatabase _db() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  const groupId = 'g1';
  const userId = 'u1';
  final now = DateTime(2024);

  late AppDatabase db;
  late CorrectionMemoryService memory;
  late CalibratedScorer scorer;

  Future<void> canonical({
    required String id,
    required String nameDe,
    String nameEn = '',
  }) {
    return db.upsertCanonicalItems([
      CanonicalItemsTableCompanion.insert(
        id: id,
        groupId: '__global__',
        nameDe: Value(nameDe),
        nameEn: Value(nameEn),
        isGlobal: const Value(true),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  var aliasSeq = 0;
  Future<void> alias({
    required String canonicalItemId,
    required String aliasText,
  }) {
    return db.upsertItemAliases([
      ItemAliasesTableCompanion.insert(
        id: 'alias-${aliasSeq++}',
        groupId: '__global__',
        canonicalItemId: canonicalItemId,
        aliasText: aliasText,
        source: const Value('seed'),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  setUp(() {
    db = _db();
    memory = CorrectionMemoryService(db);
    scorer = CalibratedScorer();
    aliasSeq = 0;
  });

  tearDown(() async {
    await db.close();
  });

  test('reject demotes an otherwise auto-accepted exact alias', () async {
    const itemA = 'item-a';
    await canonical(id: itemA, nameDe: 'Melk');
    await alias(canonicalItemId: itemA, aliasText: 'melk');

    final resolver = EnsembleResolver(db, scorer: scorer);
    final before = await resolver.resolve('melk', groupId);
    expect(before.canonicalItemId, equals(itemA));
    expect(before.score, greaterThanOrEqualTo(scorer.tauAuto));

    await memory.recordReject(
      groupId: groupId,
      userId: userId,
      rawText: 'melk',
      rejectedCanonicalItemId: itemA,
    );

    final after = await resolver.resolve('melk', groupId);
    expect(after.canonicalItemId, equals(itemA));
    expect(after.score, lessThan(scorer.tauAuto));
  });

  test('reject for item A does not demote item B for the same text', () async {
    const itemA = 'item-a';
    const itemB = 'item-b';
    await canonical(id: itemA, nameDe: 'Other milk');
    await canonical(id: itemB, nameDe: 'Melk');
    await alias(canonicalItemId: itemA, aliasText: 'melk');
    await alias(canonicalItemId: itemB, aliasText: 'melk');

    await memory.recordReject(
      groupId: groupId,
      userId: userId,
      rawText: 'melk',
      rejectedCanonicalItemId: itemA,
    );

    final resolver = EnsembleResolver(db, scorer: scorer);
    final result = await resolver.resolve('melk', groupId);

    expect(result.canonicalItemId, equals(itemB));
    expect(result.score, greaterThanOrEqualTo(scorer.tauAuto));
  });

  test('recordReject stores raw text with resolver normalisation', () async {
    await memory.recordReject(
      groupId: groupId,
      userId: userId,
      rawText: 'Melk  ',
    );

    final rows = await db.getRejectCorrections(
      groupId: groupId,
      rawText: 'melk',
    );

    expect(rows, hasLength(1));
    expect(rows.single.rawText, equals('melk'));
    expect(rows.single.kind, equals('reject'));
  });
}
