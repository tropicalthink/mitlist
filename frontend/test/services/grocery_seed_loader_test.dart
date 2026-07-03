import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/grocery_seed_loader.dart';
import 'package:mitlist/storage/app_database.dart';

const _seedAsset = 'assets/grocery/seed.json';
const _seedVersionAsset = 'assets/grocery/seed.version.json';
const _storeAislesAsset = 'assets/grocery/store_aisles.json';
const _globalGroupId = '__global__';

class _CountingBundle extends AssetBundle {
  final Map<String, String> assets;
  final Map<String, int> loads = {};

  _CountingBundle(this.assets);

  int count(String key) => loads[key] ?? 0;

  @override
  Future<ByteData> load(String key) async => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loads[key] = count(key) + 1;
    final value = assets[key];
    if (value == null) {
      throw Exception('asset $key not found');
    }
    return value;
  }
}

AppDatabase _memoryDb() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

String _seedJson({required int version}) => jsonEncode({
      'version': version,
      'items': [
        {
          'id': 'oat_milk',
          'name_de': 'Hafermilch',
          'name_en': 'Oat milk',
          'name_fr': 'Lait d avoine',
          'name_es': 'Leche de avena',
          'category': 'dairy',
          'default_unit': 'l',
          'aliases_de': ['haferdrink'],
          'aliases_en': ['oat drink'],
          'aliases_fr': <String>[],
          'aliases_es': <String>[],
        },
      ],
    });

String _sidecarJson(int version) => jsonEncode({'version': version});

String _storeAislesJson() => jsonEncode({
      'version': 1,
      'aisles': <Map<String, Object?>>[],
    });

Future<void> _insertExistingSeedItem(AppDatabase db) async {
  final now = DateTime.now();
  await db.upsertCanonicalItems([
    CanonicalItemsTableCompanion.insert(
      id: 'existing',
      groupId: _globalGroupId,
      nameDe: const Value('Alt'),
      nameEn: const Value('Existing'),
      category: const Value('pantry'),
      defaultUnit: const Value('pc'),
      isGlobal: const Value(true),
      version: const Value(0),
      createdAt: now,
      updatedAt: now,
    ),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GrocerySeedLoader', () {
    test('uses sidecar version to skip loading the large seed asset', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      await _insertExistingSeedItem(db);
      await db.setGroceryVersion(_globalGroupId, 5);

      final bundle = _CountingBundle({
        _seedVersionAsset: _sidecarJson(5),
        _storeAislesAsset: _storeAislesJson(),
      });

      await GrocerySeedLoader(db, bundle: bundle).loadIfNeeded();

      expect(bundle.count(_seedVersionAsset), 1);
      expect(bundle.count(_seedAsset), 0);
      expect(await db.getGroceryVersion(_globalGroupId), 5);
    });

    test('loads and records the seed when sidecar is newer', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      await db.setGroceryVersion(_globalGroupId, 4);

      final bundle = _CountingBundle({
        _seedVersionAsset: _sidecarJson(5),
        _seedAsset: _seedJson(version: 5),
        _storeAislesAsset: _storeAislesJson(),
      });

      await GrocerySeedLoader(db, bundle: bundle).loadIfNeeded();

      expect(bundle.count(_seedAsset), 1);
      expect(await db.getGroceryVersion(_globalGroupId), 5);
      final items = await db.getCanonicalItemsByGroup(_globalGroupId);
      expect(items.map((e) => e.id), contains('oat_milk'));
    });

    test('falls back to full seed check when sidecar is absent', () async {
      final db = _memoryDb();
      addTearDown(db.close);

      final bundle = _CountingBundle({
        _seedAsset: _seedJson(version: 5),
        _storeAislesAsset: _storeAislesJson(),
      });

      await GrocerySeedLoader(db, bundle: bundle).loadIfNeeded();

      expect(bundle.count(_seedVersionAsset), 1);
      expect(bundle.count(_seedAsset), 1);
      expect(await db.getGroceryVersion(_globalGroupId), 5);
    });
  });
}
