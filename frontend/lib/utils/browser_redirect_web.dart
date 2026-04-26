// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

bool get supportsBrowserRedirect => true;

Uri browserCurrentUri() => Uri.base;

String browserOrigin() => html.window.location.origin;

void redirectBrowser(String url) {
  html.window.location.assign(url);
}
