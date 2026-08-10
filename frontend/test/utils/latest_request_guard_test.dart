import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/utils/latest_request_guard.dart';

void main() {
  test('only the latest request remains current', () {
    final guard = LatestRequestGuard();
    final first = guard.begin();
    final second = guard.begin();

    expect(guard.isCurrent(first), isFalse);
    expect(guard.isCurrent(second), isTrue);
  });

  test('invalidate and dispose reject outstanding requests', () {
    final guard = LatestRequestGuard();
    final invalidated = guard.begin();
    guard.invalidate();
    expect(guard.isCurrent(invalidated), isFalse);

    final disposed = guard.begin();
    guard.dispose();
    expect(guard.isCurrent(disposed), isFalse);
  });
}
