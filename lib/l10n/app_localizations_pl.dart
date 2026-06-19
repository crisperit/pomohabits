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
  String get homeHabitsTooltip => 'Nawyki';

  @override
  String get habitsTitle => 'Nawyki';

  @override
  String get habitsEmpty => 'Brak nawyków.';

  @override
  String get habitsRefreshTooltip => 'Odśwież';

  @override
  String get habitsLoadError => 'Nie udało się wczytać nawyków.';

  @override
  String get addHabitTitle => 'Dodaj nawyk';

  @override
  String get habitNameLabel => 'Nazwa';

  @override
  String get habitCategoryLabel => 'Kategoria';

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
  String get addHabitButton => 'Dodaj nawyk';

  @override
  String get habitAddedSuccess => 'Nawyk dodany.';

  @override
  String get habitErrorNameRequired => 'Podaj nazwę nawyku.';

  @override
  String get habitErrorNameTooLong => 'Nazwa może mieć maksymalnie 200 znaków.';

  @override
  String get habitErrorNameDuplicate => 'Nawyk o tej nazwie już istnieje.';

  @override
  String get habitErrorUnexpected =>
      'Nie udało się dodać nawyku. Spróbuj ponownie.';

  @override
  String get habitIconLabel => 'Ikona';

  @override
  String get habitIconRemove => 'Usuń';

  @override
  String get breakSuggestionStretch => 'Wstań i rozciągnij się';

  @override
  String get breakSuggestionHydrate => 'Wypij szklankę wody';

  @override
  String get breakSuggestionLookAway =>
      'Popatrz na coś odległego przez 20 sekund';

  @override
  String get breakSuggestionBreathe => 'Weź pięć głębokich, powolnych oddechów';

  @override
  String get breakSuggestionWalk => 'Przejdź się przez chwilę';

  @override
  String get focusTitle => 'Skupienie';

  @override
  String get focusReady => 'Gotowy';

  @override
  String get focusPhaseFocus => 'Skupienie';

  @override
  String get focusPhaseShortBreak => 'Krótka przerwa';

  @override
  String get focusPhaseLongBreak => 'Długa przerwa';

  @override
  String get focusStart => 'Rozpocznij sesję skupienia';

  @override
  String get focusPause => 'Wstrzymaj';

  @override
  String get focusResume => 'Wznów';

  @override
  String get focusStop => 'Zatrzymaj';

  @override
  String get breakAlwaysShownLabel => 'Zawsze widoczne';

  @override
  String get breakRandomLabel => 'Twój wybór na tę przerwę';

  @override
  String get breakSuggestionLabel => 'Spróbuj tego';

  @override
  String get breakEndButton => 'Zakończ przerwę';

  @override
  String get breakRollAgain => 'Losuj ponownie';

  @override
  String get breakMarkComplete => 'Oznacz jako zrobione';

  @override
  String get breakCompletedLabel => 'Zrobione';

  @override
  String get breakCompleteError => 'Nie udało się zapisać. Spróbuj ponownie.';
}
