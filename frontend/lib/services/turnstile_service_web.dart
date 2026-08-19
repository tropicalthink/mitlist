// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../config/turnstile_config.dart';
import 'turnstile_provider.dart';

/// `window.turnstile`, present once the Cloudflare script in web/index.html has
/// loaded. Explicit rendering (`?render=explicit`) means the script never hunts
/// the DOM for widgets on its own, so nothing appears until we ask.
@JS('turnstile')
external _TurnstileApi? get _turnstileApi;

extension type _TurnstileApi._(JSObject _) implements JSObject {
  external String render(web.HTMLElement container, JSObject options);
  external void remove(String widgetId);
}

/// Fetches Turnstile tokens for web guest sign-up.
///
/// Each call renders a fresh widget: Turnstile tokens are single-use and
/// short-lived, so caching one would produce a token the API has already seen.
class TurnstileService implements TurnstileTokenProvider {
  TurnstileService._();

  static final TurnstileService instance = TurnstileService._();

  /// How long to wait for the Cloudflare script, then for the challenge. The
  /// script wait is short because it is either cached or blocked; the
  /// challenge wait is generous because an invisible widget may still be
  /// working through a proof.
  static const Duration _scriptTimeout = Duration(seconds: 5);
  static const Duration _challengeTimeout = Duration(seconds: 20);

  @override
  Future<String?> getToken() async {
    if (!TurnstileConfig.enabled) return null;

    final api = await _waitForScript();
    if (api == null) {
      throw const TurnstileUnavailableException(
        'Secure guest sign-up is unavailable because the verification script '
        'could not load. Check for a blocker and try again.',
      );
    }

    // Off-screen rather than display:none — a display:none container makes
    // some browsers skip layout for the iframe, and Turnstile needs it laid
    // out to run.
    final container = web.document.createElement('div') as web.HTMLElement;
    container.style.position = 'absolute';
    container.style.left = '-9999px';
    container.style.top = '0';
    container.style.width = '300px';
    container.style.height = '65px';
    web.document.body?.append(container);

    final completer = Completer<String?>();
    String? widgetId;

    void finish(String? token) {
      if (!completer.isCompleted) completer.complete(token);
    }

    try {
      // Built property by property rather than with jsify(): the values are
      // already-converted JS callbacks, which jsify() is not specified to pass
      // through untouched.
      final options = JSObject();
      options.setProperty('sitekey'.toJS, TurnstileConfig.siteKey.toJS);
      options.setProperty('action'.toJS, 'guest'.toJS);
      options.setProperty(
        'callback'.toJS,
        ((JSString token) => finish(token.toDart)).toJS,
      );
      options.setProperty(
        'error-callback'.toJS,
        ((JSAny? _) => finish(null)).toJS,
      );
      options.setProperty(
        'timeout-callback'.toJS,
        ((JSAny? _) => finish(null)).toJS,
      );

      widgetId = api.render(container, options);

      final token = await completer.future.timeout(
        _challengeTimeout,
        onTimeout: () => null,
      );
      if (token == null || token.isEmpty) {
        throw const TurnstileUnavailableException(
          'Secure guest sign-up could not be verified. Please try again.',
        );
      }
      return token;
    } finally {
      if (widgetId != null) {
        api.remove(widgetId);
      }
      container.remove();
    }
  }

  /// The script tag is `async defer`, so `window.turnstile` may not exist yet
  /// when the first guest sign-up happens on a cold load.
  Future<_TurnstileApi?> _waitForScript() async {
    const step = Duration(milliseconds: 100);
    var waited = Duration.zero;
    while (waited < _scriptTimeout) {
      final api = _turnstileApi;
      if (api != null) return api;
      await Future<void>.delayed(step);
      waited += step;
    }
    return _turnstileApi;
  }
}
