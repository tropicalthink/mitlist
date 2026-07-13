import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations_en.dart';
import 'package:mitlist/utils/invite_link.dart';

void main() {
  group('buildInviteLink', () {
    test('builds link with uppercased trimmed code', () {
      expect(buildInviteLink('ab-12'), 'mitlist:///join/AB-12');
    });

    test('trims surrounding whitespace', () {
      expect(buildInviteLink('  ABCD  '), 'mitlist:///join/ABCD');
    });

    test('uppercases mixed case', () {
      expect(buildInviteLink('sunny-taco'), 'mitlist:///join/SUNNY-TACO');
    });
  });

  group('extractInviteCode', () {
    test('accepts a bare code, uppercased', () {
      expect(extractInviteCode('sunny-taco-42'), 'SUNNY-TACO-42');
    });

    test('trims surrounding whitespace', () {
      expect(extractInviteCode('  ABCD-1234  '), 'ABCD-1234');
    });

    test('pulls the code from a mitlist deep link', () {
      expect(extractInviteCode('mitlist:///join/ABCD-1234'), 'ABCD-1234');
    });

    test('pulls the code from an https web invite link', () {
      expect(
        extractInviteCode('https://mitlist.me/join/sunny-taco'),
        'SUNNY-TACO',
      );
    });

    test('handles a link with a trailing slash or query', () {
      expect(
        extractInviteCode('https://mitlist.me/join/ABCD-1234?ref=sms'),
        'ABCD-1234',
      );
    });

    test('returns null for empty or whitespace-only input', () {
      expect(extractInviteCode(''), isNull);
      expect(extractInviteCode('   '), isNull);
    });

    test('returns null for a too-short code', () {
      expect(extractInviteCode('ab'), isNull);
    });

    test('returns null for arbitrary non-code text', () {
      expect(extractInviteCode('hey, join my household!'), isNull);
    });
  });

  group('parseInviteCode', () {
    test('returns code for a valid join link', () {
      expect(
        parseInviteCode(Uri.parse('mitlist:///join/ABCD-1234')),
        'ABCD-1234',
      );
    });

    test('returns null for wrong scheme', () {
      expect(
        parseInviteCode(Uri.parse('https://join/ABCD-1234')),
        isNull,
      );
    });

    test('returns null for wrong path', () {
      expect(
        parseInviteCode(Uri.parse('mitlist:///auth/callback')),
        isNull,
      );
    });

    test('returns null when code is too short (< 4 chars)', () {
      expect(
        parseInviteCode(Uri.parse('mitlist:///join/AB')),
        isNull,
      );
    });

    test('returns null for empty path', () {
      expect(
        parseInviteCode(Uri.parse('mitlist:///join/')),
        isNull,
      );
    });

    test('returns null when code contains invalid characters', () {
      expect(
        parseInviteCode(Uri.parse('mitlist:///join/ABCD!@#\$')),
        isNull,
      );
    });

    test('accepts exactly 4 chars', () {
      expect(
        parseInviteCode(Uri.parse('mitlist:///join/ABCD')),
        'ABCD',
      );
    });
  });

  group('inviteShareText', () {
    final l10n = AppLocalizationsEn();

    test('contains the bare code at least twice', () {
      const code = 'SUNNY-TACO-42';
      final text = inviteShareText(code, l10n);
      expect(
        code.allMatches(text).length,
        greaterThanOrEqualTo(2),
        reason: 'code should appear in the link and as a standalone value',
      );
    });

    test('contains an https link', () {
      final text = inviteShareText('ABCD-1234', l10n);
      expect(text, contains('https://'));
      expect(text, contains('/join/ABCD-1234'));
    });

    test('lowercased input is uppercased in output', () {
      final text = inviteShareText('ab-12', l10n);
      expect(text, contains('AB-12'));
      expect(text, isNot(contains('ab-12')));
    });

    test('contains a standalone code line (for copy-paste)', () {
      final text = inviteShareText('TEST-CODE-99', l10n);
      expect(text, contains('TEST-CODE-99'));
      // The text includes a line with just the code (no URL formatting)
      expect(text, contains('enter the code: TEST-CODE-99'));
    });
  });
}
