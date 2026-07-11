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
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 250)));
  });
}
