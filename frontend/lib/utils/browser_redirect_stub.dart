bool get supportsBrowserRedirect => false;

Uri browserCurrentUri() => Uri.base;

String browserOrigin() => Uri.base.origin;

void redirectBrowser(String url) {}
