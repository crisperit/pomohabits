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
  String get homeTasksTooltip => 'Tasks';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String get tasksEmpty => 'No tasks yet.';

  @override
  String get tasksRefreshTooltip => 'Refresh';

  @override
  String get tasksLoadError => 'Could not load tasks.';

  @override
  String get addTaskTitle => 'Add task';

  @override
  String get taskNameLabel => 'Name';

  @override
  String get taskCategoryLabel => 'Category';

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
  String get addTaskButton => 'Add task';

  @override
  String get taskAddedSuccess => 'Task added.';

  @override
  String get taskErrorNameRequired => 'Please enter a task name.';

  @override
  String get taskErrorNameTooLong => 'Name must be 200 characters or fewer.';

  @override
  String get taskErrorNameDuplicate => 'A task with this name already exists.';

  @override
  String get taskErrorUnexpected => 'Could not add the task. Please try again.';

  @override
  String get taskIconLabel => 'Icon';

  @override
  String get taskIconHint => 'Optional emoji';

  @override
  String get taskErrorIconTooLong => 'Enter one emoji or leave empty.';
}
