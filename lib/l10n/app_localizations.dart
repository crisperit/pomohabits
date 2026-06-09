import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

  /// Application name shown in the app bar
  ///
  /// In en, this message translates to:
  /// **'Taskodoro'**
  String get appTitle;

  /// Title of the Settings page
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Section header for theme selection in Settings
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// Radio option: follow the OS theme
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeSystem;

  /// Radio option: force light theme
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Radio option: force dark theme
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Section header for language selection in Settings
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get localeLabel;

  /// Radio option: use the device locale
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get localeSystem;

  /// Radio option: force English locale
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localeEnglish;

  /// Radio option: force Polish locale
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get localePolish;

  /// Label for the Close button in the Settings dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Label for the name field on the sign-up form
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get authNameLabel;

  /// Label for the email field on the auth form
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Label for the password field on the auth form
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Label for the confirm-password field on the sign-up form
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPasswordLabel;

  /// Label for the sign-in submit button
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInButton;

  /// Label for the sign-up submit button
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUpButton;

  /// Link text to switch from sign-in mode to sign-up mode
  ///
  /// In en, this message translates to:
  /// **'Need an account? Sign up'**
  String get authToggleToSignUp;

  /// Link text to switch from sign-up mode to sign-in mode
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authToggleToSignIn;

  /// Label for the sign-out action
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// Label for the resend confirmation email button
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get authResendButton;

  /// Link text to return from the awaiting-confirmation screen to sign-in mode
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authBackToSignIn;

  /// Title shown on the awaiting-confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authCheckEmailTitle;

  /// Body text shown on the awaiting-confirmation screen
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Open it to finish signing up.'**
  String authCheckEmailBody(String email);

  /// Feedback shown after successfully resending the confirmation email
  ///
  /// In en, this message translates to:
  /// **'Confirmation email sent again.'**
  String get authResendSuccess;

  /// Validation error when the name field is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get authErrorNameRequired;

  /// Validation error when the email field is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get authErrorEmailRequired;

  /// Validation error when the email field contains an invalid address
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email.'**
  String get authErrorEmailInvalid;

  /// Validation error when the password is shorter than 6 characters
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authErrorPasswordTooShort;

  /// Validation error when the confirm-password field does not match the password
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authErrorPasswordMismatch;

  /// Fallback error message shown when a non-AuthException error occurs during auth
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorUnexpected;

  /// Greeting shown on the home screen with the user's name
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String homeGreeting(String name);

  /// Tooltip for the Tasks icon button on the home screen AppBar
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get homeTasksTooltip;

  /// Title of the Tasks configuration page
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTitle;

  /// Message shown on the Tasks page when the list is empty
  ///
  /// In en, this message translates to:
  /// **'No tasks yet.'**
  String get tasksEmpty;

  /// Tooltip for the refresh icon button on the Tasks page AppBar
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get tasksRefreshTooltip;

  /// Error message shown on the Tasks page when loading fails
  ///
  /// In en, this message translates to:
  /// **'Could not load tasks.'**
  String get tasksLoadError;

  /// Title of the Add Task form page
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addTaskTitle;

  /// Label for the task name text field on the Add Task form
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get taskNameLabel;

  /// Label for the category dropdown on the Add Task form
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get taskCategoryLabel;

  /// Dropdown option for the one-time task category
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get categoryOneTime;

  /// Dropdown option for the daily task category
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get categoryDaily;

  /// Dropdown option for the unlimited task category
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get categoryUnlimited;

  /// Label for the break window dropdown on the Add Task form
  ///
  /// In en, this message translates to:
  /// **'Break window'**
  String get breakWindowLabel;

  /// Dropdown option for the short break window
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get breakWindowShort;

  /// Dropdown option for the long break window
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get breakWindowLong;

  /// Dropdown option for both break windows
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get breakWindowBoth;

  /// Label for the always-shown toggle on the Add Task form
  ///
  /// In en, this message translates to:
  /// **'Always shown'**
  String get alwaysShownLabel;

  /// Label for the submit button on the Add Task form
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addTaskButton;

  /// Snackbar message shown after a task is successfully added
  ///
  /// In en, this message translates to:
  /// **'Task added.'**
  String get taskAddedSuccess;

  /// Validation error when the task name field is empty or whitespace
  ///
  /// In en, this message translates to:
  /// **'Please enter a task name.'**
  String get taskErrorNameRequired;

  /// Validation error when the task name exceeds 200 characters
  ///
  /// In en, this message translates to:
  /// **'Name must be 200 characters or fewer.'**
  String get taskErrorNameTooLong;

  /// Validation error when the task name matches an existing task (case-insensitive)
  ///
  /// In en, this message translates to:
  /// **'A task with this name already exists.'**
  String get taskErrorNameDuplicate;

  /// Fallback error message shown when a non-PostgrestException error occurs during task add
  ///
  /// In en, this message translates to:
  /// **'Could not add the task. Please try again.'**
  String get taskErrorUnexpected;

  /// Label for the optional emoji icon picker button on the Add Task form
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get taskIconLabel;

  /// Label for the button that clears the chosen emoji icon in the picker sheet
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get taskIconRemove;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
