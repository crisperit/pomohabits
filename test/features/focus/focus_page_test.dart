import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/features/focus/focus_session.dart';
import 'package:pomohabits/features/focus/focus_session_controller.dart';
import 'package:pomohabits/features/focus/presentation/focus_page.dart';
import 'package:pomohabits/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake controller notifier: records method calls, returns a fixed state.
// ---------------------------------------------------------------------------

class _FakeFocusController extends FocusSessionController {
  _FakeFocusController(this._state);

  final FocusSessionState _state;

  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;

  @override
  FocusSessionState build() => _state;

  @override
  void start() => startCalls++;

  @override
  void pause() => pauseCalls++;

  @override
  void resume() => resumeCalls++;

  @override
  void stop() => stopCalls++;

  @override
  void reset() => stopCalls++;
}

// ---------------------------------------------------------------------------
// Test harness helper
// ---------------------------------------------------------------------------

Future<_FakeFocusController> _pumpFocusPage(
  WidgetTester tester,
  FocusSessionState sessionState,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final fake = _FakeFocusController(sessionState);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        focusSessionControllerProvider.overrideWith(() => fake),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FocusPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

// ---------------------------------------------------------------------------
// formatRemaining unit tests
// ---------------------------------------------------------------------------

void main() {
  group('formatRemaining', () {
    test('formats 25 minutes as 25:00', () {
      expect(formatRemaining(const Duration(minutes: 25)), '25:00');
    });

    test('formats 5 minutes 9 seconds as 05:09', () {
      expect(formatRemaining(const Duration(minutes: 5, seconds: 9)), '05:09');
    });

    test('formats zero as 00:00', () {
      expect(formatRemaining(Duration.zero), '00:00');
    });

    test('formats 1 second as 00:01', () {
      expect(formatRemaining(const Duration(seconds: 1)), '00:01');
    });

    test('formats 59 seconds as 00:59', () {
      expect(formatRemaining(const Duration(seconds: 59)), '00:59');
    });

    test('formats 1 minute exactly as 01:00', () {
      expect(formatRemaining(const Duration(minutes: 1)), '01:00');
    });

    test('formats 15 minutes as 15:00', () {
      expect(formatRemaining(const Duration(minutes: 15)), '15:00');
    });
  });

  group('FocusPage', () {
    group('idle state', () {
      testWidgets('shows work duration preview (25:00) not 00:00',
          (tester) async {
        await _pumpFocusPage(tester, const FocusSessionState.initial());

        expect(find.text('25:00'), findsOneWidget);
        expect(find.text('00:00'), findsNothing);
      });

      testWidgets('shows Start focus session button', (tester) async {
        await _pumpFocusPage(tester, const FocusSessionState.initial());

        expect(find.text('Start focus session'), findsOneWidget);
      });

      testWidgets('does not show Pause, Resume, or Stop buttons',
          (tester) async {
        await _pumpFocusPage(tester, const FocusSessionState.initial());

        expect(find.text('Pause'), findsNothing);
        expect(find.text('Resume'), findsNothing);
        expect(find.text('Stop'), findsNothing);
      });

      testWidgets('tapping Start calls controller.start()', (tester) async {
        final fake = await _pumpFocusPage(
          tester,
          const FocusSessionState.initial(),
        );

        await tester.tap(find.text('Start focus session'));
        await tester.pump();

        expect(fake.startCalls, 1);
      });
    });

    group('running focus state', () {
      testWidgets('shows formatted remaining time (20:05)', (tester) async {
        await _pumpFocusPage(
          tester,
          const FocusSessionState(
            phase: FocusPhase.focus,
            remaining: Duration(minutes: 20, seconds: 5),
            isRunning: true,
            completedFocusSessions: 0,
          ),
        );

        expect(find.text('20:05'), findsOneWidget);
      });

      testWidgets('shows Pause and Stop buttons', (tester) async {
        await _pumpFocusPage(
          tester,
          const FocusSessionState(
            phase: FocusPhase.focus,
            remaining: Duration(minutes: 20, seconds: 5),
            isRunning: true,
            completedFocusSessions: 0,
          ),
        );

        expect(find.text('Pause'), findsOneWidget);
        expect(find.text('Stop'), findsOneWidget);
      });

      testWidgets('does not show Start or Resume', (tester) async {
        await _pumpFocusPage(
          tester,
          const FocusSessionState(
            phase: FocusPhase.focus,
            remaining: Duration(minutes: 20, seconds: 5),
            isRunning: true,
            completedFocusSessions: 0,
          ),
        );

        expect(find.text('Start focus session'), findsNothing);
        expect(find.text('Resume'), findsNothing);
      });

      testWidgets('tapping Pause calls controller.pause()', (tester) async {
        final fake = await _pumpFocusPage(
          tester,
          const FocusSessionState(
            phase: FocusPhase.focus,
            remaining: Duration(minutes: 20, seconds: 5),
            isRunning: true,
            completedFocusSessions: 0,
          ),
        );

        await tester.tap(find.text('Pause'));
        await tester.pump();

        expect(fake.pauseCalls, 1);
      });

      testWidgets('tapping Stop calls controller.stop()', (tester) async {
        final fake = await _pumpFocusPage(
          tester,
          const FocusSessionState(
            phase: FocusPhase.focus,
            remaining: Duration(minutes: 20, seconds: 5),
            isRunning: true,
            completedFocusSessions: 0,
          ),
        );

        await tester.tap(find.text('Stop'));
        await tester.pump();

        expect(fake.stopCalls, 1);
      });
    });

    group('paused state', () {
      testWidgets('shows formatted remaining time (18:30)', (tester) async {
        await _pumpFocusPage(
          tester,
          const FocusSessionState(
            phase: FocusPhase.focus,
            remaining: Duration(minutes: 18, seconds: 30),
            isRunning: false,
            completedFocusSessions: 0,
          ),
        );

        expect(find.text('18:30'), findsOneWidget);
      });

      testWidgets('shows Resume and Stop buttons', (tester) async {
        await _pumpFocusPage(
          tester,
          const FocusSessionState(
            phase: FocusPhase.focus,
            remaining: Duration(minutes: 18, seconds: 30),
            isRunning: false,
            completedFocusSessions: 0,
          ),
        );

        expect(find.text('Resume'), findsOneWidget);
        expect(find.text('Stop'), findsOneWidget);
      });

      testWidgets('does not show Start or Pause', (tester) async {
        await _pumpFocusPage(
          tester,
          const FocusSessionState(
            phase: FocusPhase.focus,
            remaining: Duration(minutes: 18, seconds: 30),
            isRunning: false,
            completedFocusSessions: 0,
          ),
        );

        expect(find.text('Start focus session'), findsNothing);
        expect(find.text('Pause'), findsNothing);
      });

      testWidgets('tapping Resume calls controller.resume()', (tester) async {
        final fake = await _pumpFocusPage(
          tester,
          const FocusSessionState(
            phase: FocusPhase.focus,
            remaining: Duration(minutes: 18, seconds: 30),
            isRunning: false,
            completedFocusSessions: 0,
          ),
        );

        await tester.tap(find.text('Resume'));
        await tester.pump();

        expect(fake.resumeCalls, 1);
      });

      testWidgets('tapping Stop calls controller.stop()', (tester) async {
        final fake = await _pumpFocusPage(
          tester,
          const FocusSessionState(
            phase: FocusPhase.focus,
            remaining: Duration(minutes: 18, seconds: 30),
            isRunning: false,
            completedFocusSessions: 0,
          ),
        );

        await tester.tap(find.text('Stop'));
        await tester.pump();

        expect(fake.stopCalls, 1);
      });
    });
  });
}
