// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcomeTagline => 'Your household, organized.';

  @override
  String get welcomeCardTitle => 'Lists, chores, money.\nAll in one place.';

  @override
  String get welcomeCardBody =>
      'Built for flatmates who want less friction and more clarity.';

  @override
  String get welcomeCreateHousehold => 'Create free household';

  @override
  String get welcomeSignIn => 'Sign in';

  @override
  String get welcomeGuestLoading => 'Setting up...';

  @override
  String get welcomeContinueAsGuest => 'Continue as guest';

  @override
  String get welcomeGuestFootnote =>
      'No account needed. Try everything free for 30 days.';
}
