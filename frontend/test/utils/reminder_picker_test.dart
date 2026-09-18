import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/utils/reminder_picker.dart';

void main() {
  final now = DateTime(2026, 9, 18, 14, 30);

  group('reminderPickerSeed', () {
    test('uses now when there is no existing reminder', () {
      expect(reminderPickerSeed(null, now), now);
    });

    test('keeps a reminder that is still in the future', () {
      final future = DateTime(2026, 9, 20, 9, 15);
      expect(reminderPickerSeed(future, now), future);
    });

    test('falls back to now, including the time of day, once a reminder '
        'has already fired', () {
      final past = DateTime(2026, 9, 17, 9, 15);
      final seed = reminderPickerSeed(past, now);
      expect(seed, now);
      expect(seed.hour, 14);
      expect(seed.minute, 30);
    });

    test('treats a reminder equal to now as elapsed', () {
      expect(reminderPickerSeed(now, now), now);
    });
  });
}
