// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Taskodoro';

  @override
  String get signInPlaceholder =>
      'Ekran logowania nie jest jeszcze zbudowany (S-01)';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get themeLabel => 'Motyw';

  @override
  String get themeSystem => 'Auto';

  @override
  String get themeLight => 'Jasny';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get localeLabel => 'Język';

  @override
  String get localeSystem => 'Auto';

  @override
  String get localeEnglish => 'Angielski';

  @override
  String get localePolish => 'Polski';

  @override
  String get close => 'Zamknij';
}
