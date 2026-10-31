// Which receipt lines become purchases, on the real shipped catalog.
//
// Receipt text is shorthand, and the catalog alone links some of it
// confidently to the wrong product ("TUNA STEAKS" -> Tuna Salad, "ORANGE NET"
// -> Orange Zest). The matcher only accepts items the household already
// keeps track of. This runs the six Commons receipts against a simulated
// household that has bought everyday versions of what is on them.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/canonical_link_service.dart';
import 'package:mitlist/services/scan/canonical_resolver_service.dart';
import 'package:mitlist/services/scan/receipt_parser.dart';
import 'package:mitlist/services/scan/receipt_purchase_matcher.dart';
import 'package:mitlist/services/scan/scan_models.dart';
import 'package:mitlist/services/scan/static_embedding_service.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/storage/grocery_reference_database.dart';

import '../../support/grocery_seed_test_helper.dart';

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

ReceiptReading _receipt(String id) {
  final json = jsonDecode(
    File('test/fixtures/receipts/$id.ocr.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return const ReceiptParser().parse([
    for (final line in (json['lines'] as List).cast<Map<String, dynamic>>())
      OcrLine(
        text: line['text'] as String,
        bbox: () {
          final b = (line['bbox'] as List).cast<num>();
          return OcrBBox(b[0].toDouble(), b[1].toDouble(), b[2].toDouble(),
              b[3].toDouble());
        }(),
      ),
  ], now: DateTime(2026, 10, 31));
}

/// Everyday items the simulated household has bought before.
const _household = [
  'orange',
  'tuna',
  'banana',
  'apple',
  'grape_juice',
  'apple_juice',
  'cheddar',
  'peas',
  'corn',
  'rice',
  'mineral_water',
  'cookies',
  'doughnut',
  'bread_roll',
  'milk',
  'pancake',
  'porridge',
  'quark',
  'apple_spritzer',
  'granola_bar',
  'milk_roll',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ReceiptPurchaseMatcher matcher;

  setUpAll(() async {
    db = memoryDb();
    db.attachReference(GroceryReferenceDatabase.open(_installReferenceDb()));
    matcher = ReceiptPurchaseMatcher(
      db,
      CanonicalLinkService(CanonicalResolverService(db,
          embedder: _realEmbedder(), useEnsemble: true)),
    );
    var n = 0;
    for (final id in _household) {
      for (var week = 0; week < 3; week++) {
        await db.insertPurchaseHistory(PurchaseHistoryTableCompanion.insert(
          id: 'p${n++}',
          groupId: 'home',
          canonicalItemId: Value(id),
          purchasedAt: DateTime(2026, 9, 1 + 7 * week),
        ));
      }
    }
  });

  tearDownAll(() => db.close());

  Future<Map<String, double>> bought(String receipt) async => {
        for (final p in await matcher.match(_receipt(receipt), 'home'))
          p.canonicalItemId: p.quantity,
      };

  test('receipt lines become the household\'s own items', () async {
    expect(await bought('aldi_2006'),
        {'apple_spritzer': 2, 'grape_juice': 3, 'granola_bar': 1});
    expect(await bought('lidl_aurich_2019'), {'milk_roll': 1});
    // "ORANGE NET" is the household's oranges, not orange zest; "TUNA
    // STEAKS" links to tuna salad, which this household never buys.
    expect(await bought('tesco_1994'), {'cookies': 1, 'rice': 1, 'orange': 1});
    expect(await bought('woolworths'), {'apple': 1, 'banana': 1});
    expect(await bought('savemart_2010'), isEmpty);
    expect(await bought('italian_iva'), isEmpty);
  });

  test('a household with no history learns nothing from a receipt', () async {
    expect(await matcher.match(_receipt('aldi_2006'), 'new-home'), isEmpty);
  });
}
