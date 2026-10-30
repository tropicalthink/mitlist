// Regression gate for grocery resolution on the shipped catalog.
//
// Runs the production resolver and typed-suggestion ranking against the real
// bundled reference database and embedder over test/fixtures/
// resolution_gold.jsonl: everyday shopping words in English and German,
// plurals, brands, typos, and lines that are not groceries at all.
//
// It guards what a person notices: an item silently linked to the wrong
// product (confident-wrong), everyday words that never link (and so never
// feed restock, aisles or expense categories), and the first suggestion
// offered while typing. Set GOLD_REPORT=1 to print every line.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/household_prior_service.dart';
import 'package:mitlist/services/scan/canonical_link_service.dart';
import 'package:mitlist/services/scan/canonical_resolver_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/services/scan/static_embedding_service.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/storage/grocery_reference_database.dart';

import '../support/grocery_seed_test_helper.dart';

class _GoldEntry {
  _GoldEntry(this.text, this.accept);
  final String text;
  final Set<String> accept;
  bool get isGrocery => accept.isNotEmpty;
}

List<_GoldEntry> _loadGold() => File('test/fixtures/resolution_gold.jsonl')
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty && !line.startsWith('#'))
        .map((line) {
      final json = jsonDecode(line) as Map<String, dynamic>;
      return _GoldEntry(
        json['text'] as String,
        (json['accept'] as List).cast<String>().toSet(),
      );
    }).toList();

String _installReferenceDb() {
  final dir = Directory.systemTemp.createTempSync('gold-ref');
  final path = '${dir.path}/grocery_ref.sqlite';
  final gz = File('assets/grocery/grocery_ref.sqlite.gz').readAsBytesSync();
  File(path).writeAsBytesSync(gzip.decode(gz));
  return path;
}

StaticEmbeddingService _realEmbedder() {
  final vocab =
      jsonDecode(File('assets/grocery/embedder_vocab.json').readAsStringSync())
          as Map<String, dynamic>;
  final catalog =
      jsonDecode(File('assets/grocery/catalog_vectors.json').readAsStringSync())
          as Map<String, dynamic>;
  List<Float32List> dequantise(List rows, int dim, double scale) => [
        for (final row in rows)
          Float32List.fromList([
            for (var i = 0; i < dim; i++) ((row as List)[i] as num) * scale,
          ]),
      ];
  return StaticEmbeddingService()
    ..seedForTest(
      vocab: (vocab['vocab'] as List).cast<String>(),
      vocabVectors: dequantise(vocab['vectors_int8'] as List,
          vocab['dim'] as int, (vocab['scale'] as num).toDouble()),
      itemIds: (catalog['item_ids'] as List).cast<String>(),
      catalogVectors: dequantise(catalog['vectors_int8'] as List,
          catalog['dim'] as int, (catalog['scale'] as num).toDouble()),
    );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CanonicalResolverService resolver;
  late GrocerySuggestionService suggestions;
  final gold = _loadGold();

  setUpAll(() {
    db = memoryDb();
    db.attachReference(GroceryReferenceDatabase.open(_installReferenceDb()));
    final embedder = _realEmbedder();
    resolver =
        CanonicalResolverService(db, embedder: embedder, useEnsemble: true);
    suggestions = GrocerySuggestionService(
      db,
      prior: HouseholdPriorService(db),
      embedder: embedder,
    );
  });

  tearDownAll(() => db.close());

  test('shipped catalog resolves everyday shopping words', () async {
    final report = Platform.environment['GOLD_REPORT'] != null;
    var groceries = 0;
    var linked = 0;
    var topSuggestionRight = 0;
    final confidentWrong = <String>[];
    final linkedNonGrocery = <String>[];

    for (final entry in gold) {
      final result = await resolver.resolve(entry.text, 'gold-household');
      final linkedId = CanonicalLinkService.acceptedCanonicalId(result);
      final top = await suggestions.suggest(
        entry.text,
        'gold-household',
        suggestionContext: GrocerySuggestionContext.shoppingList,
        limit: 3,
      );
      final topId = top.isEmpty ? null : top.first.canonicalItemId;

      if (entry.isGrocery) {
        groceries++;
        if (linkedId != null) {
          if (entry.accept.contains(linkedId)) {
            linked++;
          } else {
            confidentWrong.add('${entry.text} → $linkedId');
          }
        }
        if (topId != null && entry.accept.contains(topId)) {
          topSuggestionRight++;
        }
      } else if (linkedId != null) {
        linkedNonGrocery.add('${entry.text} → $linkedId');
      }
      if (report) {
        // ignore: avoid_print
        print('${linkedId == null ? '----' : 'LINK'} '
            '${entry.text.padRight(18)} ${result.score.toStringAsFixed(2)} '
            '${result.canonicalItemId} | top=$topId | want=${entry.accept}');
      }
    }

    final linkRate = linked / groceries;
    final topRate = topSuggestionRight / groceries;
    // ignore: avoid_print
    print('gold: $groceries groceries, linked ${(linkRate * 100).round()}%, '
        'top suggestion right ${(topRate * 100).round()}%, '
        'confident-wrong ${confidentWrong.length}, '
        'non-grocery linked ${linkedNonGrocery.length}');

    expect(confidentWrong, isEmpty,
        reason: 'an item silently linked to the wrong product');
    expect(linkedNonGrocery, isEmpty,
        reason: 'a line that is not groceries was linked');
    expect(linkRate, greaterThanOrEqualTo(kGoldMinLinkRate));
    expect(topRate, greaterThanOrEqualTo(kGoldMinTopSuggestionRate));
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// Floors set from the measured result, a few points under it. Raise them
/// when the catalog or resolver improves; never lower them to pass.
const double kGoldMinLinkRate = 0.95;
const double kGoldMinTopSuggestionRate = 0.95;
