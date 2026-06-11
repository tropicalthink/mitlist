import 'package:url_launcher/url_launcher.dart';

/// True if [url] parses and has an http/https scheme.
bool isSafeExternalUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}

/// Launches [url] externally only if [isSafeExternalUrl]. Returns true if a
/// launch was attempted successfully.
Future<bool> safeLaunchUrl(String url) async {
  if (!isSafeExternalUrl(url)) return false;
  try {
    return await launchUrl(Uri.parse(url.trim()), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
