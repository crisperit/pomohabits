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

  @override
  String get authNameLabel => 'Imię';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Hasło';

  @override
  String get authConfirmPasswordLabel => 'Potwierdź hasło';

  @override
  String get authSignInButton => 'Zaloguj się';

  @override
  String get authSignUpButton => 'Zarejestruj się';

  @override
  String get authToggleToSignUp => 'Nie masz konta? Zarejestruj się';

  @override
  String get authToggleToSignIn => 'Masz już konto? Zaloguj się';

  @override
  String get authSignOut => 'Wyloguj się';

  @override
  String get authResendButton => 'Wyślij ponownie';

  @override
  String get authBackToSignIn => 'Wróć do logowania';

  @override
  String get authCheckEmailTitle => 'Sprawdź skrzynkę';

  @override
  String authCheckEmailBody(String email) {
    return 'Wysłaliśmy link potwierdzający na adres $email. Otwórz go, aby dokończyć rejestrację.';
  }

  @override
  String get authResendSuccess =>
      'Email potwierdzający został wysłany ponownie.';

  @override
  String get authErrorNameRequired => 'Podaj swoje imię.';

  @override
  String get authErrorEmailRequired => 'Podaj swój email.';

  @override
  String get authErrorEmailInvalid => 'Podaj prawidłowy email.';

  @override
  String get authErrorPasswordTooShort =>
      'Hasło musi mieć co najmniej 6 znaków.';

  @override
  String get authErrorPasswordMismatch => 'Hasła nie są takie same.';

  @override
  String get authErrorUnexpected => 'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String homeGreeting(String name) {
    return 'Cześć, $name';
  }

  @override
  String get homeTasksTooltip => 'Zadania';

  @override
  String get tasksTitle => 'Zadania';

  @override
  String get tasksEmpty => 'Brak zadań.';

  @override
  String get tasksRefreshTooltip => 'Odśwież';

  @override
  String get tasksLoadError => 'Nie udało się wczytać zadań.';

  @override
  String get addTaskTitle => 'Dodaj zadanie';

  @override
  String get taskNameLabel => 'Nazwa';

  @override
  String get taskCategoryLabel => 'Kategoria';

  @override
  String get categoryOneTime => 'Jednorazowe';

  @override
  String get categoryDaily => 'Codzienne';

  @override
  String get categoryUnlimited => 'Bez limitu';

  @override
  String get breakWindowLabel => 'Okno przerwy';

  @override
  String get breakWindowShort => 'Krótka';

  @override
  String get breakWindowLong => 'Długa';

  @override
  String get breakWindowBoth => 'Obie';

  @override
  String get alwaysShownLabel => 'Zawsze widoczne';

  @override
  String get addTaskButton => 'Dodaj zadanie';

  @override
  String get taskAddedSuccess => 'Zadanie dodane.';

  @override
  String get taskErrorNameRequired => 'Podaj nazwę zadania.';

  @override
  String get taskErrorNameTooLong => 'Nazwa może mieć maksymalnie 200 znaków.';

  @override
  String get taskErrorNameDuplicate => 'Zadanie o tej nazwie już istnieje.';

  @override
  String get taskErrorUnexpected =>
      'Nie udało się dodać zadania. Spróbuj ponownie.';

  @override
  String get taskIconLabel => 'Ikona';

  @override
  String get taskIconHint => 'Opcjonalne emoji';

  @override
  String get taskErrorIconTooLong => 'Wpisz jedno emoji lub zostaw puste.';
}
