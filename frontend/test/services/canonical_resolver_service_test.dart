// Tests for CanonicalResolverService with optional classifier fallback.
//
// Uses an in-memory Drift database (NativeDatabase.memory()) — requires
// the sqlite3 native library on the host.  The fake classifier subclass
// overrides classify() to return scripted predictions without any model I/O.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/canonical_resolver_service.dart';
import 'package:mitlist/services/scan/grocery_classifier_service.dart';
import 'package:mitlist/storage/app_database.dart';

// ---------------------------------------------------------------------------
// Fake classifier — returns scripted predictions without any asset I/O.
// ---------------------------------------------------------------------------

class _FakeClassifier extends GroceryClassifierService {
  List<ClassifierPrediction> Function(String)? _handler;

  _FakeClassifier() : super();

  void setHandler(List<ClassifierPrediction> Function(String text) handler) {
    _handler = handler;
  }

  @override
  Future<List<ClassifierPrediction>> classify(String rawText,
      {int topK = 5}) async {
    if (_handler == null) return const [];
    return _handler!(rawText);
  }
}

// ---------------------------------------------------------------------------
// Helpers to seed the in-memory DB.
// ---------------------------------------------------------------------------

final _now = DateTime(2024, 1, 1);

Future<void> _seedCanonicalItem(
  AppDatabase db, {
  required String id,
  required String nameDe,
  String nameEn = '',
  String groupId = '__global__',
}) async {
  await db.upsertCanonicalItems([
    CanonicalItemsTableCompanion.insert(
      id: id,
      groupId: groupId,
      nameDe: drift.Value(nameDe),
      nameEn: drift.Value(nameEn),
      isGlobal: const drift.Value(true),
      createdAt: _now,
      updatedAt: _now,
    ),
  ]);
}

Future<void> _seedAlias(
  AppDatabase db, {
  required String id,
  required String canonicalItemId,
  required String aliasText,
  String groupId = '__global__',
}) async {
  await db.upsertItemAliases([
    ItemAliasesTableCompanion.insert(
      id: id,
      groupId: groupId,
      canonicalItemId: canonicalItemId,
      aliasText: aliasText,
      createdAt: _now,
      updatedAt: _now,
    ),
  ]);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late _FakeClassifier fakeClassifier;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    fakeClassifier = _FakeClassifier();
  });

  tearDown(() async {
    await db.close();
  });

  group('No classifier (backward-compatible behaviour)', () {
    test('low-confidence input returns score 0 without classifier', () async {
      final resolver = CanonicalResolverService(db);
      // 'xyznothing' has no alias → fuzzy candidates are empty → score 0.
      final result = await resolver.resolve('xyznothing', 'hh-1');
      expect(result.score, equals(0));
      expect(result.canonicalItemId, isNull);
    });

    test('exact alias match returns score 1.0 without classifier', () async {
      await _seedCanonicalItem(db, id: 'item-milk', nameDe: 'vollmilch');
      await _seedAlias(
          db, id: 'a-milk', canonicalItemId: 'item-milk', aliasText: 'vollmilch');

      final resolver = CanonicalResolverService(db);
      final result = await resolver.resolve('Vollmilch', 'hh-1');
      expect(result.score, equals(1.0));
      expect(result.canonicalItemId, equals('item-milk'));
    });
  });

  group('Classifier fallback wiring', () {
    test('confident classifier + label maps to seeded item → model wins', () async {
      await _seedCanonicalItem(db, id: 'item-banana', nameDe: 'bananen');
      await _seedAlias(
          db, id: 'a-banana', canonicalItemId: 'item-banana', aliasText: 'bananen');

      fakeClassifier.setHandler((_) => [
            const ClassifierPrediction(label: 'bananen', score: 0.92),
            const ClassifierPrediction(label: 'äpfel', score: 0.05),
          ]);

      final resolver = CanonicalResolverService(db, classifier: fakeClassifier);
      // Input that won't fuzzy-match anything precisely.
      final result = await resolver.resolve('bnannen', 'hh-1');
      expect(result.canonicalItemId, equals('item-banana'));
      expect(result.score, closeTo(0.92, 1e-6));
      expect(result.displayName, equals('Bananen'));
    });

    test('classifier score < 0.85 → fuzzy result kept', () async {
      await _seedCanonicalItem(db, id: 'item-banana', nameDe: 'bananen');
      await _seedAlias(
          db, id: 'a-banana', canonicalItemId: 'item-banana', aliasText: 'bananen');

      // Weak classifier prediction — below the 0.85 threshold.
      fakeClassifier.setHandler((_) => [
            const ClassifierPrediction(label: 'bananen', score: 0.60),
          ]);

      final resolver = CanonicalResolverService(db, classifier: fakeClassifier);
      final result = await resolver.resolve('xyznothing', 'hh-1');
      // Fuzzy gave score 0 (no candidates); classifier weak → keep fuzzy.
      expect(result.score, equals(0));
      expect(result.canonicalItemId, isNull);
    });

    test('classifier confident but label not in alias table → fuzzy kept, no crash',
        () async {
      // No canonical item or alias seeded for the predicted label.
      fakeClassifier.setHandler((_) => [
            const ClassifierPrediction(label: 'unbekannt', score: 0.95),
          ]);

      final resolver = CanonicalResolverService(db, classifier: fakeClassifier);
      // Should not throw; falls back to fuzzy (score 0).
      final result = await resolver.resolve('etwas', 'hh-1');
      expect(result.canonicalItemId, isNull);
      expect(result.score, equals(0));
    });

    test('classifier returns empty list → fuzzy result kept', () async {
      fakeClassifier.setHandler((_) => const []);

      final resolver = CanonicalResolverService(db, classifier: fakeClassifier);
      final result = await resolver.resolve('xyznothing', 'hh-1');
      expect(result.score, equals(0));
      expect(result.canonicalItemId, isNull);
    });
  });

  group('Existing call sites keep compiling (optional arg)', () {
    test('CanonicalResolverService(db) compiles and works without classifier arg',
        () async {
      // This guard test ensures the constructor is backward-compatible.
      final resolver = CanonicalResolverService(db);
      expect(resolver, isNotNull);
    });
  });
}
