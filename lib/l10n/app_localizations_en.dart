// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Taskodoro';

  @override
  String get signInPlaceholder => 'Sign-in screen is not built yet (S-01)';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSystem => 'Auto';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get localeLabel => 'Language';

  @override
  String get localeSystem => 'Auto';

  @override
  String get localeEnglish => 'English';

  @override
  String get localePolish => 'Polish';

  @override
  String get close => 'Close';
}
