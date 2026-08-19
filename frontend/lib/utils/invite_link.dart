// Helpers for building and parsing household invite links.
//
// Deep-link format: `mitlist:///join/<CODE>` — used internally by the router.
// Web link format:  `https://app.mitlist.me/join/<CODE>` — used for sharing.
// With Dart's Uri, `mitlist:///join/ABCD-1234` parses as:
//   scheme = 'mitlist', host = '' (empty), pathSegments = ['join', 'ABCD-1234']

import '../l10n/app_localizations.dart';

const _kWebAppUrl = String.fromEnvironment(
  'WEB_APP_URL',
  defaultValue: 'https://app.mitlist.me',
);

/// A code is "plausible" when it is ≥ 4 characters and contains only
/// alphanumerics and hyphens.
final _codePattern = RegExp(r'^[A-Za-z0-9\-]{4,}$');

/// Builds a custom-scheme deep link for [code] (used internally).
String buildInviteLink(String code) {
  final c = code.trim().toUpperCase();
  return 'mitlist:///join/$c';
}

/// Builds an HTTPS link for [code] suitable for sharing on WhatsApp, SMS, etc.
///
/// Configurable at build time via `--dart-define=WEB_APP_URL=https://your-host`.
String buildWebInviteLink(String code) {
  final c = code.trim().toUpperCase();
  return '$_kWebAppUrl/join/$c';
}

/// Extracts the invite code from [uri] when it is a valid join link.
///
/// Returns `null` if the URI scheme doesn't match, the path doesn't start
/// with 'join', or the code segment is missing or implausible
/// (< 4 chars, non-alphanumeric non-hyphen chars).
String? parseInviteCode(Uri uri) {
  if (uri.scheme != 'mitlist') return null;
  final segments = uri.pathSegments;
  if (segments.length < 2 || segments[0] != 'join') return null;
  final code = segments[1];
  if (!_codePattern.hasMatch(code)) return null;
  return code;
}

/// Extracts an invite code from arbitrary pasted [text]. Accepts a bare code,
/// a `mitlist:///join/<code>` deep link, or an `https://.../join/<code>` web
/// link (the form people actually receive over chat/SMS). Returns the
/// uppercased code, or `null` when nothing plausible is found.
String? extractInviteCode(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  // A link — pull the segment right after 'join' regardless of scheme/host.
  final uri = Uri.tryParse(trimmed);
  if (uri != null) {
    final segments = uri.pathSegments;
    final joinIdx = segments.indexOf('join');
    if (joinIdx >= 0 && joinIdx + 1 < segments.length) {
      final code = segments[joinIdx + 1];
      if (_codePattern.hasMatch(code)) return code.toUpperCase();
    }
  }

  // Otherwise treat the whole clipboard as a bare code if it looks like one.
  if (_codePattern.hasMatch(trimmed)) return trimmed.toUpperCase();
  return null;
}

/// Builds a shareable text message with a web link for WhatsApp/social sharing.
String inviteShareText(String code, AppLocalizations l10n) {
  final c = code.trim().toUpperCase();
  return l10n.inviteLinkShareText(buildWebInviteLink(c), c);
}
