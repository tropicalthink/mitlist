// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:web/web.dart';

bool get supportsBrowserRedirect => true;

Uri browserCurrentUri() => Uri.base;

String browserOrigin() => window.location.origin;

void redirectBrowser(String url) {
  window.location.assign(url);
}
