import 'package:flutter/widgets.dart' show Locale, basicLocaleListResolution;

import '../l10n/app_localizations.dart';
import '../models/auth_models.dart';

/// The language the app is showing: the one picked under You, or else the
/// device language resolved against the shipped translations the same way
/// [MaterialApp] resolves it (which falls back to the first supported locale,
/// not to English).
String effectiveLanguageCode(Locale? chosen, List<Locale> deviceLocales) {
  if (chosen != null) return chosen.languageCode;
  return basicLocaleListResolution(
    deviceLocales,
    AppLocalizations.supportedLocales,
  ).languageCode;
}

/// Preference key holding the last `<userId>:<language>` this device queued
/// for the server.
const kQueuedServerLanguageKey = 'server_language_queued';

/// Decides whether the app's language must be queued for the server, which
/// writes email in it. Returns the marker to remember once queued, or null
/// when there is nothing to do: a guest (no email address), no known account
/// yet, or this exact language already queued for this account. Works from
/// local state only, so it answers offline; the outbox delivers the change.
String? languageToQueueMarker({
  required String language,
  required User? me,
  required String? lastQueued,
}) {
  if (me == null || me.isGuest) return null;
  final marker = '${me.id}:$language';
  return marker == lastQueued ? null : marker;
}
