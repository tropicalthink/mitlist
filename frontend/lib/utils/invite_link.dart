// Helpers for building and parsing household invite links.
//
// Deep-link format: `mitlist://join/<CODE>` — used internally by the router.
// Web link format:  `https://mitlist.me/join/<CODE>` — used for sharing.
// With Dart's Uri, `mitlist://join/ABCD-1234` parses as:
//   scheme = 'mitlist', host = 'join', pathSegments = ['ABCD-1234']

import '../l10n/app_localizations.dart';

const _kWebAppUrl = String.fromEnvironment(
  'WEB_APP_URL',
  defaultValue: 'https://mitlist.me',
);

/// A code is "plausible" when it is ≥ 4 characters and contains only
/// alphanumerics and hyphens.
final _codePattern = RegExp(r'^[A-Za-z0-9\-]{4,}$');

/// Builds a custom-scheme deep link for [code] (used internally).
String buildInviteLink(String code) {
  final c = code.trim().toUpperCase();
  return 'mitlist://join/$c';
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
/// Returns `null` if the URI scheme/host don't match or the code segment
/// is missing or implausible (< 4 chars, non-alphanumeric non-hyphen chars).
String? parseInviteCode(Uri uri) {
  if (uri.scheme != 'mitlist') return null;
  if (uri.host != 'join') return null;
  final segments = uri.pathSegments;
  if (segments.isEmpty) return null;
  final code = segments.first;
  if (!_codePattern.hasMatch(code)) return null;
  return code;
}

/// Builds a shareable text message with a web link for WhatsApp/social sharing.
String inviteShareText(String code, AppLocalizations l10n) {
  final c = code.trim().toUpperCase();
  return l10n.inviteLinkShareText(buildWebInviteLink(c), c);
}
