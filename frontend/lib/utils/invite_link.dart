// Helpers for building and parsing household invite deep links.
//
// Link format: `mitlist://join/<CODE>` (code trimmed + uppercased).
// With Dart's Uri, `mitlist://join/ABCD-1234` parses as:
//   scheme = 'mitlist', host = 'join', pathSegments = ['ABCD-1234']

/// A code is "plausible" when it is ≥ 4 characters and contains only
/// alphanumerics and hyphens.
final _codePattern = RegExp(r'^[A-Za-z0-9\-]{4,}$');

/// Builds a deep link for [code].
///
/// The code is trimmed and uppercased before embedding.
String buildInviteLink(String code) {
  final c = code.trim().toUpperCase();
  return 'mitlist://join/$c';
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

/// Builds a shareable text message containing the invite link and the bare
/// code so the invite is useful even where custom-scheme links aren't
/// auto-linkified.
String inviteShareText(String code) {
  final c = code.trim().toUpperCase();
  return 'Join my household on mitlist!\n'
      'Tap: ${buildInviteLink(c)}\n'
      'Or open mitlist and enter the code: $c';
}
