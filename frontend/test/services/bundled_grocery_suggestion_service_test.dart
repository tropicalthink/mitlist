import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/bundled_grocery_suggestion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns canonical-name suggestions without a seeded database',
      () async {
    final service = BundledGrocerySuggestionService();
    final stopwatch = Stopwatch()..start();

    final suggestions = await service.suggest('mil');
    stopwatch.stop();

    expect(suggestions, isNotEmpty);
    expect(
      suggestions
          .any((suggestion) => suggestion.name.toLowerCase().startsWith('mil')),
      isTrue,
    );
    // Debug CI may run this beside the full 280k-row seed stress test. Keep the
    // guard wide enough for scheduler contention while still catching the old
    // multi-second full-seed decode/isolate path.
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('nearest tolerates a wrong first character from handwriting OCR',
      () async {
    final matches = await BundledGrocerySuggestionService().nearest('Aliverol');

    expect(matches, isNotEmpty);
    expect(matches.first.canonicalItemId, 'olive_oil');
    expect(matches.first.similarity, greaterThanOrEqualTo(0.65));
  });
}
