import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/services/server_language_sync.dart';

User _user({String? language, bool isGuest = false}) => User(
      id: 'u1',
      email: 'a@example.com',
      firstName: 'Ada',
      lastName: 'L',
      isActive: true,
      isVerified: true,
      isGuest: isGuest,
      language: language,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  group('effectiveLanguageCode', () {
    test('an explicit choice wins over the device', () {
      expect(
        effectiveLanguageCode(const Locale('nl'), const [Locale('fr', 'FR')]),
        'nl',
      );
    });

    test('System follows a supported device language', () {
      expect(effectiveLanguageCode(null, const [Locale('fr', 'CA')]), 'fr');
      expect(
        effectiveLanguageCode(null, const [Locale('it'), Locale('es')]),
        'es',
      );
    });

    test('an unsupported device language reports what the app falls back to',
        () {
      // MaterialApp shows the first supported locale when nothing matches;
      // the server must get that same language, not a guess.
      final shown = basicLocaleListResolution(
        const [Locale('it')],
        const [Locale('de'), Locale('en'), Locale('es')],
      ).languageCode;
      expect(shown, 'de');
      expect(effectiveLanguageCode(null, const [Locale('it')]), 'de');
    });
  });

  group('languageToQueueMarker', () {
    test('a new language for this account is queued', () {
      expect(
        languageToQueueMarker(language: 'de', me: _user(), lastQueued: 'u1:en'),
        'u1:de',
      );
      expect(
        languageToQueueMarker(language: 'de', me: _user(), lastQueued: null),
        'u1:de',
      );
    });

    test('the same language is not queued twice', () {
      expect(
        languageToQueueMarker(language: 'de', me: _user(), lastQueued: 'u1:de'),
        isNull,
      );
    });

    test('another account on this device queues its own', () {
      expect(
        languageToQueueMarker(
            language: 'de', me: _user(), lastQueued: 'someone-else:de'),
        'u1:de',
      );
    });

    test('guests and unknown accounts queue nothing', () {
      expect(
        languageToQueueMarker(
            language: 'de', me: _user(isGuest: true), lastQueued: null),
        isNull,
      );
      expect(
        languageToQueueMarker(language: 'de', me: null, lastQueued: null),
        isNull,
      );
    });
  });

  test('language round-trips through the user and update models', () {
    final user = User.fromJson(_user(language: 'fr').toJson());
    expect(user.language, 'fr');
    expect(
        const UpdateUserRequest(language: 'nl').toJson(), {'language': 'nl'});
    expect(const UpdateUserRequest().toJson(), isEmpty);
  });
}
