import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/suggestion_service.dart';
import 'package:mitlist/storage/app_database.dart';

AppDatabase _db() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  late AppDatabase db;
  final now = DateTime(2024, 1, 1);

  Future<void> seedItem({
    required String id,
    required String name,
  }) async {
    await db.upsertCanonicalItems([
      CanonicalItemsTableCompanion.insert(
        id: id,
        groupId: '__global__',
        nameDe: Value(name),
        nameEn: Value(name),
        isGlobal: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  setUp(() {
    db = _db();
  });

  tearDown(() async {
    await db.close();
  });

  test('suggestions include trigger-based reason', () async {
    await seedItem(id: 'milk', name: 'milk');
    await seedItem(id: 'cereal', name: 'cereal');
    await db.upsertCooccurrence([
      ItemCooccurrenceTableCompanion.insert(
        groupId: 'hh-1',
        itemAId: 'milk',
        itemBId: 'cereal',
        count: const Value(4),
        lastSeenAt: now,
      ),
    ]);

    final service = SuggestionService(db);
    final suggestions = await service.suggest(
      groupId: 'hh-1',
      presentCanonicalIds: ['milk'],
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.canonicalItemId, 'cereal');
    expect(suggestions.single.displayName, 'Cereal');
    expect(suggestions.single.reason, 'often with milk');
    expect(suggestions.single.score, 4);
  });
}
