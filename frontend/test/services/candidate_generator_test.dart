import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/canonical_resolver_service.dart';
import 'package:mitlist/services/scan/resolution/candidate_generator.dart';
import 'package:mitlist/services/scan/resolution/resolution_candidate.dart';
import 'package:mitlist/storage/app_database.dart';

// CandidateGenerator over an in-memory Drift DB. Proves the union + dedup +
// source attribution that the old sequential resolver lacked — especially that
// a colliding word surfaces ALL the items it maps to, not just one.

AppDatabase _db() => AppDatabase(
      DatabaseConnection(NativeDatabase.memory(),
          closeStreamsSynchronously: true),
    );

void main() {
  late AppDatabase db;
  final now = DateTime(2020);

  Future<void> canonical(String id, String de, String en) =>
      db.upsertCanonicalItems([
        CanonicalItemsTableCompanion.insert(
          id: id,
          groupId: '__global__',
          nameDe: Value(de),
          nameEn: Value(en),
          isGlobal: const Value(true),
          version: const Value(0),
          createdAt: now,
          updatedAt: now,
        )
      ]);

  var aliasSeq = 0;
  Future<void> alias(String group, String canonicalId, String text,
          {String source = 'seed'}) =>
      db.upsertItemAliases([
        ItemAliasesTableCompanion.insert(
          id: 'al${aliasSeq++}',
          groupId: group,
          canonicalItemId: canonicalId,
          aliasText: text,
          source: Value(source),
          version: const Value(0),
          createdAt: now,
          updatedAt: now,
        )
      ]);

  setUp(() async {
    db = _db();
    await canonical('spaghetti', 'Spaghetti', 'Spaghetti');
    await canonical('egg_spaghetti', 'Eierspaghetti', 'Egg Spaghetti');
    await canonical('milk', 'Milch', 'Milk');
    await canonical('peanut_butter', 'Erdnussbutter', 'Peanut Butter');
    // The collision: "spaghetti" is both spaghetti's name and an egg_spaghetti alias.
    await alias('__global__', 'spaghetti', 'spaghetti');
    await alias('__global__', 'egg_spaghetti', 'spaghetti');
    await alias('__global__', 'egg_spaghetti', 'eierspaghetti');
    await alias('__global__', 'milk', 'milch');
    // A household-confirmed correction (not global seed).
    await alias('h1', 'peanut_butter', 'pb', source: 'correction');
  });

  tearDown(() => db.close());

  ResolutionCandidate? pick(List<ResolutionCandidate> cs, String id) =>
      cs.where((c) => c.canonicalItemId == id).firstOrNull;

  test('exact collision surfaces ALL matching items as candidates', () async {
    final cs = await CandidateGenerator(db).generate('Spaghetti', 'h1');
    final ids = cs.map((c) => c.canonicalItemId).toSet();
    expect(ids, containsAll(['spaghetti', 'egg_spaghetti']));
    expect(pick(cs, 'spaghetti')!.isExactAlias, isTrue);
    expect(pick(cs, 'egg_spaghetti')!.isExactAlias, isTrue);
    expect(pick(cs, 'spaghetti')!.aliasStringSim, 1.0);
  });

  test('fuzzy neighbour is admitted with sub-1.0 similarity', () async {
    final cs = await CandidateGenerator(db).generate('mlch', 'h1');
    final milk = pick(cs, 'milk');
    expect(milk, isNotNull);
    expect(milk!.sources, contains('fuzzy'));
    expect(milk.aliasStringSim, greaterThan(0.4));
    expect(milk.aliasStringSim, lessThan(1.0));
  });

  test('household-scoped alias is flagged isHouseholdAlias', () async {
    final cs = await CandidateGenerator(db).generate('pb', 'h1');
    final pb = pick(cs, 'peanut_butter');
    expect(pb, isNotNull);
    expect(pb!.isHouseholdAlias, isTrue);
    expect(pb.sources, contains('household_alias'));
  });

  test('a global alias for a different household is NOT household-scoped',
      () async {
    final cs = await CandidateGenerator(db).generate('Spaghetti', 'h1');
    expect(pick(cs, 'spaghetti')!.isHouseholdAlias, isFalse);
    expect(pick(cs, 'spaghetti')!.sources, contains('global_alias'));
  });

  test('empty / whitespace query yields no candidates', () async {
    expect(await CandidateGenerator(db).generate('   ', 'h1'), isEmpty);
  });

  group('CanonicalResolverService useEnsemble flag', () {
    test('ensemble path resolves the collision to the right canonical item',
        () async {
      // "spaghetti" is an alias of BOTH spaghetti and egg_spaghetti. The
      // ensemble disambiguates via canonicalNameSim (its own name matches).
      final ens = CanonicalResolverService(db, useEnsemble: true);
      final r = await ens.resolve('Spaghetti', 'h1');
      expect(r.canonicalItemId, 'spaghetti');
      expect(r.score, greaterThan(0.85)); // confident & correct
    });

    test('default (sequential) path is unchanged and still compiles', () async {
      final seq = CanonicalResolverService(db); // useEnsemble defaults false
      final r = await seq.resolve('milch', 'h1');
      expect(r.canonicalItemId, 'milk');
    });
  });
}
