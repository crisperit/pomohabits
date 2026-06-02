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
  String homeGreeting(String name) {
    return 'Hello, $name';
  }
}
