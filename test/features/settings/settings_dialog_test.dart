import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/features/settings/presentation/settings_dialog.dart';
import 'package:pomohabits/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test harness helper
// ---------------------------------------------------------------------------

/// Pumps [SettingsDialog] inside a minimal [MaterialApp] with full l10n and a
/// real [timerConfigProvider] backed by an in-memory [SharedPreferences].
Future<ProviderContainer> _pumpSettingsDialog(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  late ProviderContainer container;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SettingsDialog(),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Enters [text] in the field identified by [key], then submits it via
/// [TextInputAction.done] to trigger persistence.
Future<void> _enterAndSubmit(
  WidgetTester tester,
  ValueKey<String> key,
  String text,
) async {
  await tester.enterText(find.byKey(key), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Enters [text] in the field identified by [key], then drops focus entirely
/// to trigger the focus-loss persistence path.
Future<void> _enterAndUnfocus(
  WidgetTester tester,
  ValueKey<String> key,
  String text,
) async {
  await tester.enterText(find.byKey(key), text);
  // Drop focus on the primary focus node — works regardless of scroll position.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SettingsDialog – timer section', () {
    // -----------------------------------------------------------------------
    // Render
    // -----------------------------------------------------------------------

    testWidgets('four timer fields render with default config values',
        (tester) async {
      await _pumpSettingsDialog(tester);

      // Work field seeded with 25 (default).
      final workField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('timerWorkField')),
          matching: find.byType(EditableText),
        ),
      );
      expect(workField.controller.text, '25');

      // Short break field seeded with 5 (default).
      final shortBreakField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('timerShortBreakField')),
          matching: find.byType(EditableText),
        ),
      );
      expect(shortBreakField.controller.text, '5');

      // Long break field seeded with 15 (default).
      final longBreakField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('timerLongBreakField')),
          matching: find.byType(EditableText),
        ),
      );
      expect(longBreakField.controller.text, '15');

      // Sessions field seeded with 4 (default).
      final sessionsField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('timerSessionsField')),
          matching: find.byType(EditableText),
        ),
      );
      expect(sessionsField.controller.text, '4');
    });

    // -----------------------------------------------------------------------
    // Work field
    // -----------------------------------------------------------------------

    testWidgets(
        'entering 0 in work field shows a range error and does NOT '
        'update timerConfigProvider', (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey('timerWorkField')),
        '0',
      );
      await tester.pumpAndSettle();

      // Validation error is visible.
      expect(
        find.textContaining('Enter a number between'),
        findsAtLeastNWidgets(1),
      );

      // Provider state is unchanged: still the default 25 min.
      final config = container.read(timerConfigProvider);
      expect(config.workDuration, const Duration(minutes: 25));
    });

    testWidgets(
        'entering 999 in the work field shows a range error and does NOT '
        'update timerConfigProvider', (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey('timerWorkField')),
        '999',
      );
      await tester.pumpAndSettle();

      // Validation error is visible.
      expect(
        find.textContaining('Enter a number between'),
        findsAtLeastNWidgets(1),
      );

      // Provider state is unchanged.
      final config = container.read(timerConfigProvider);
      expect(config.workDuration, const Duration(minutes: 25));
    });

    testWidgets(
        'entering a valid work value and submitting updates timerConfigProvider',
        (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await _enterAndSubmit(
        tester,
        const ValueKey('timerWorkField'),
        '30',
      );

      // No range error shown.
      expect(find.textContaining('Enter a number between'), findsNothing);

      // Provider updated to the new value.
      final config = container.read(timerConfigProvider);
      expect(config.workDuration, const Duration(minutes: 30));
    });

    testWidgets(
        'entering a valid work value and unfocusing updates timerConfigProvider',
        (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await _enterAndUnfocus(
        tester,
        const ValueKey('timerWorkField'),
        '20',
      );

      final config = container.read(timerConfigProvider);
      expect(config.workDuration, const Duration(minutes: 20));
    });

    // -----------------------------------------------------------------------
    // Short break field
    // -----------------------------------------------------------------------

    testWidgets(
        'entering 0 in short break field shows a range error and does NOT '
        'update timerConfigProvider', (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey('timerShortBreakField')),
        '0',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Enter a number between'),
        findsAtLeastNWidgets(1),
      );

      final config = container.read(timerConfigProvider);
      expect(config.shortBreakDuration, const Duration(minutes: 5));
    });

    testWidgets(
        'entering 999 in the short break field shows a range error and does NOT '
        'update timerConfigProvider', (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey('timerShortBreakField')),
        '999',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Enter a number between'),
        findsAtLeastNWidgets(1),
      );

      final config = container.read(timerConfigProvider);
      expect(config.shortBreakDuration, const Duration(minutes: 5));
    });

    testWidgets(
        'entering a valid short break value and submitting updates timerConfigProvider',
        (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await _enterAndSubmit(
        tester,
        const ValueKey('timerShortBreakField'),
        '10',
      );

      expect(find.textContaining('Enter a number between'), findsNothing);

      final config = container.read(timerConfigProvider);
      expect(config.shortBreakDuration, const Duration(minutes: 10));
    });

    // -----------------------------------------------------------------------
    // Long break field
    // -----------------------------------------------------------------------

    testWidgets(
        'entering 0 in long break field shows a range error and does NOT '
        'update timerConfigProvider', (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey('timerLongBreakField')),
        '0',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Enter a number between'),
        findsAtLeastNWidgets(1),
      );

      final config = container.read(timerConfigProvider);
      expect(config.longBreakDuration, const Duration(minutes: 15));
    });

    testWidgets(
        'entering 999 in the long break field shows a range error and does NOT '
        'update timerConfigProvider', (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey('timerLongBreakField')),
        '999',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Enter a number between'),
        findsAtLeastNWidgets(1),
      );

      final config = container.read(timerConfigProvider);
      expect(config.longBreakDuration, const Duration(minutes: 15));
    });

    testWidgets(
        'entering a valid long break value and submitting updates timerConfigProvider',
        (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await _enterAndSubmit(
        tester,
        const ValueKey('timerLongBreakField'),
        '20',
      );

      expect(find.textContaining('Enter a number between'), findsNothing);

      final config = container.read(timerConfigProvider);
      expect(config.longBreakDuration, const Duration(minutes: 20));
    });

    // -----------------------------------------------------------------------
    // Sessions field
    // -----------------------------------------------------------------------

    testWidgets(
        'entering 0 in sessions field shows a range error and does NOT '
        'update timerConfigProvider', (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey('timerSessionsField')),
        '0',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Enter a number between'),
        findsAtLeastNWidgets(1),
      );

      final config = container.read(timerConfigProvider);
      expect(config.sessionsUntilLongBreak, 4);
    });

    testWidgets(
        'entering 99 in the sessions field shows a range error and does NOT '
        'update timerConfigProvider', (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey('timerSessionsField')),
        '99',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Enter a number between'),
        findsAtLeastNWidgets(1),
      );

      final config = container.read(timerConfigProvider);
      expect(config.sessionsUntilLongBreak, 4);
    });

    testWidgets(
        'entering a valid sessions value and submitting updates timerConfigProvider',
        (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await _enterAndSubmit(
        tester,
        const ValueKey('timerSessionsField'),
        '6',
      );

      expect(find.textContaining('Enter a number between'), findsNothing);

      final config = container.read(timerConfigProvider);
      expect(config.sessionsUntilLongBreak, 6);
    });

    // -----------------------------------------------------------------------
    // Empty field
    // -----------------------------------------------------------------------

    testWidgets(
        'clearing a field shows a range error and does NOT update timerConfigProvider',
        (tester) async {
      final container = await _pumpSettingsDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey('timerWorkField')),
        '',
      );
      await tester.pumpAndSettle();

      // Error visible for the empty field.
      expect(
        find.textContaining('Enter a number between'),
        findsAtLeastNWidgets(1),
      );

      // Provider unchanged.
      final config = container.read(timerConfigProvider);
      expect(config.workDuration, const Duration(minutes: 25));
    });
  });
}
