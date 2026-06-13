// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get welcomeTagline => 'Dein Haushalt, organisiert.';

  @override
  String get welcomeCardTitle => 'Listen, Aufgaben, Geld.\nAlles an einem Ort.';

  @override
  String get welcomeCardBody =>
      'Gemacht für WGs, die weniger Reibung und mehr Klarheit wollen.';

  @override
  String get welcomeCreateHousehold => 'Kostenlosen Haushalt erstellen';

  @override
  String get welcomeSignIn => 'Anmelden';

  @override
  String get welcomeGuestLoading => 'Wird eingerichtet …';

  @override
  String get welcomeContinueAsGuest => 'Als Gast fortfahren';

  @override
  String get welcomeGuestFootnote =>
      'Kein Konto nötig. 30 Tage lang alles kostenlos testen.';
}
