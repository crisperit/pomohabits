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

  @override
  String get authNameLabel => 'Name';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authSignUpButton => 'Sign up';

  @override
  String get authToggleToSignUp => 'Need an account? Sign up';

  @override
  String get authToggleToSignIn => 'Already have an account? Sign in';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authResendButton => 'Resend email';

  @override
  String get authBackToSignIn => 'Back to sign in';

  @override
  String get authCheckEmailTitle => 'Check your email';

  @override
  String authCheckEmailBody(String email) {
    return 'We sent a confirmation link to $email. Open it to finish signing up.';
  }

  @override
  String get authResendSuccess => 'Confirmation email sent again.';

  @override
  String get authErrorNameRequired => 'Please enter your name.';

  @override
  String get authErrorEmailRequired => 'Please enter your email.';

  @override
  String get authErrorEmailInvalid => 'Please enter a valid email.';

  @override
  String get authErrorPasswordTooShort =>
      'Password must be at least 6 characters.';

  @override
  String get authErrorPasswordMismatch => 'Passwords do not match.';

  @override
  String get authErrorUnexpected => 'Something went wrong. Please try again.';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeHabitsTooltip => 'Habits';

  @override
  String get habitsTitle => 'Habits';

  @override
  String get habitsEmpty => 'No habits yet.';

  @override
  String get habitsRefreshTooltip => 'Refresh';

  @override
  String get habitsLoadError => 'Could not load habits.';

  @override
  String get addHabitTitle => 'Add habit';

  @override
  String get habitNameLabel => 'Name';

  @override
  String get habitCategoryLabel => 'Category';

  @override
  String get categoryOneTime => 'One-time';

  @override
  String get categoryDaily => 'Daily';

  @override
  String get categoryUnlimited => 'Unlimited';

  @override
  String get breakWindowLabel => 'Break window';

  @override
  String get breakWindowShort => 'Short';

  @override
  String get breakWindowLong => 'Long';

  @override
  String get breakWindowBoth => 'Both';

  @override
  String get alwaysShownLabel => 'Always shown';

  @override
  String get addHabitButton => 'Add habit';

  @override
  String get habitAddedSuccess => 'Habit added.';

  @override
  String get habitErrorNameRequired => 'Please enter a habit name.';

  @override
  String get habitErrorNameTooLong => 'Name must be 200 characters or fewer.';

  @override
  String get habitErrorNameDuplicate =>
      'A habit with this name already exists.';

  @override
  String get habitErrorUnexpected =>
      'Could not add the habit. Please try again.';

  @override
  String get habitIconLabel => 'Icon';

  @override
  String get habitIconRemove => 'Remove';

  @override
  String get breakSuggestionStretch => 'Stand up and stretch';

  @override
  String get breakSuggestionHydrate => 'Drink a glass of water';

  @override
  String get breakSuggestionLookAway => 'Look at something 20m away for 20s';

  @override
  String get breakSuggestionBreathe => 'Take five slow, deep breaths';

  @override
  String get breakSuggestionWalk => 'Walk around for a minute';

  @override
  String get focusTitle => 'Focus';

  @override
  String get focusReady => 'Ready';

  @override
  String get focusPhaseFocus => 'Focus';

  @override
  String get focusPhaseShortBreak => 'Short break';

  @override
  String get focusPhaseLongBreak => 'Long break';

  @override
  String get focusStart => 'Start focus session';

  @override
  String get focusPause => 'Pause';

  @override
  String get focusResume => 'Resume';

  @override
  String get focusStop => 'Stop';

  @override
  String get breakAlwaysShownLabel => 'Always shown';

  @override
  String get breakRandomLabel => 'Your pick for this break';

  @override
  String get breakSuggestionLabel => 'Try this';

  @override
  String get breakEndButton => 'End break';
}
