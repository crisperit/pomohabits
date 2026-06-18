import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/data/habit.dart';
import 'package:pomohabits/features/focus/focus_session.dart';
import 'package:pomohabits/features/focus/focus_session_controller.dart';
import 'package:pomohabits/features/focus/fullscreen_controller.dart';
import 'package:pomohabits/features/focus/presentation/break_screen.dart';
import 'package:pomohabits/features/habits/habits_controller.dart';
import 'package:pomohabits/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Records enter/exit calls for assertion.
class _FakeFullscreenController implements FullscreenController {
  int enterCalls = 0;
  int exitCalls = 0;

  @override
  Future<void> enter() async => enterCalls++;

  @override
  Future<void> exit() async => exitCalls++;
}

/// Fake [FocusSessionController] that holds a fixed state and records
/// [endBreak] calls.
class _FakeFocusController extends FocusSessionController {
  _FakeFocusController(this._state);

  final FocusSessionState _state;
  int endBreakCalls = 0;

  @override
  FocusSessionState build() => _state;

  @override
  void endBreak() => endBreakCalls++;

  @override
  void start() {}

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  void stop() {}

  @override
  void reset() {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A short-break session state with 4 minutes remaining.
const _shortBreakState = FocusSessionState(
  phase: FocusPhase.shortBreak,
  remaining: Duration(minutes: 4),
  isRunning: true,
  completedFocusSessions: 1,
);

/// A long-break session state with 14 minutes remaining.
const _longBreakState = FocusSessionState(
  phase: FocusPhase.longBreak,
  remaining: Duration(minutes: 14),
  isRunning: true,
  completedFocusSessions: 4,
);

Habit _habit({
  required String name,
  required bool alwaysShown,
  HabitBreakWindow window = HabitBreakWindow.both,
  String? icon,
}) =>
    Habit(
      id: name,
      name: name,
      category: HabitCategory.daily,
      applicableBreakWindow: window,
      alwaysShown: alwaysShown,
      icon: icon,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

/// Pumps [BreakScreen] wrapped in a minimal app with l10n + provider overrides.
///
/// Uses the same [AsyncValue] dispatch pattern as [habits_page_test.dart]:
/// `AsyncData` resolves immediately, `AsyncError` throws, `AsyncLoading` uses
/// a [Completer] that never resolves (no wall-clock delay needed).
Future<_FakeFocusController> _pump(
  WidgetTester tester, {
  required FocusSessionState sessionState,
  required AsyncValue<List<Habit>> habitsValue,
  bool isLongBreak = false,
  Completer<List<Habit>>? loadingCompleter,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fakeFullscreen = _FakeFullscreenController();
  final fakeFocus = _FakeFocusController(sessionState);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        fullscreenControllerProvider.overrideWithValue(fakeFullscreen),
        focusSessionControllerProvider.overrideWith(() => fakeFocus),
        habitsListProvider.overrideWith((ref) async {
          if (habitsValue is AsyncData<List<Habit>>) {
            return habitsValue.value;
          }
          if (habitsValue is AsyncError<List<Habit>>) {
            throw habitsValue.error;
          }
          // AsyncLoading: use a never-resolving Completer.
          return (loadingCompleter ?? Completer<List<Habit>>()).future;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BreakScreen(isLongBreak: isLongBreak),
      ),
    ),
  );
  await tester.pump();
  return fakeFocus;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BreakScreen', () {
    group('content: always-shown habits', () {
      testWidgets('renders always-shown eligible habits by name', (tester) async {
        final habits = [
          _habit(name: 'Drink water', alwaysShown: true),
          _habit(name: 'Stretch', alwaysShown: true),
        ];

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        expect(find.text('Drink water'), findsOneWidget);
        expect(find.text('Stretch'), findsOneWidget);
        // The always-shown section label should appear.
        expect(find.text('Always shown'), findsOneWidget);
      });

      testWidgets('renders habit icon when present', (tester) async {
        final habits = [
          _habit(name: 'Water', alwaysShown: true, icon: '\u{1F4A7}'),
        ];

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        expect(find.text('\u{1F4A7}'), findsOneWidget);
      });
    });

    group('content: randomized habit', () {
      testWidgets('renders the randomized section label and habit name',
          (tester) async {
        // One always-shown + one randomized habit.
        final habits = [
          _habit(name: 'Always here', alwaysShown: true),
          _habit(name: 'Random pick', alwaysShown: false),
        ];

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        // Both section labels should appear.
        expect(find.text('Always shown'), findsOneWidget);
        expect(find.text('Your pick for this break'), findsOneWidget);
        // The randomized habit name should appear exactly once.
        expect(find.text('Random pick'), findsOneWidget);
      });

      testWidgets('with only randomized habits, no always-shown section',
          (tester) async {
        final habits = [
          _habit(name: 'Just a pick', alwaysShown: false),
        ];

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        expect(find.text('Always shown'), findsNothing);
        expect(find.text('Your pick for this break'), findsOneWidget);
        expect(find.text('Just a pick'), findsOneWidget);
      });
    });

    group('content: built-in suggestion (empty pool)', () {
      testWidgets('renders suggestion label when pool empty', (tester) async {
        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: const AsyncData([]),
        );
        await tester.pumpAndSettle();

        // Section header should appear.
        expect(find.text('Try this'), findsOneWidget);
        // No habit section labels.
        expect(find.text('Always shown'), findsNothing);
        expect(find.text('Your pick for this break'), findsNothing);
      });
    });

    group('content: never blank (loading/error states)', () {
      testWidgets('shows suggestion while habits are loading', (tester) async {
        final completer = Completer<List<Habit>>();
        addTearDown(() {
          if (!completer.isCompleted) completer.complete(<Habit>[]);
        });

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: const AsyncLoading(),
          loadingCompleter: completer,
        );
        // Single pump -- loading future never resolves.
        await tester.pump();

        expect(find.text('Try this'), findsOneWidget);
        // No spinner -- never-blank guarantee.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('shows suggestion when habits loading errors', (tester) async {
        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncError(Exception('fail'), StackTrace.empty),
        );
        await tester.pump();

        expect(find.text('Try this'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('countdown and phase label', () {
      testWidgets('shows short break label and remaining time', (tester) async {
        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: const AsyncData([]),
        );
        await tester.pumpAndSettle();

        expect(find.text('Short break'), findsOneWidget);
        expect(find.text('04:00'), findsOneWidget);
      });

      testWidgets('shows long break label for isLongBreak: true', (tester) async {
        await _pump(
          tester,
          sessionState: _longBreakState,
          habitsValue: const AsyncData([]),
          isLongBreak: true,
        );
        await tester.pumpAndSettle();

        expect(find.text('Long break'), findsOneWidget);
        expect(find.text('14:00'), findsOneWidget);
      });
    });

    group('dismissability', () {
      testWidgets('tapping End break calls endBreak()', (tester) async {
        final fakeFocus = await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: const AsyncData([]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('End break'));
        await tester.pump();

        expect(fakeFocus.endBreakCalls, 1);
      });

      testWidgets('Escape key calls endBreak()', (tester) async {
        final fakeFocus = await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: const AsyncData([]),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(fakeFocus.endBreakCalls, 1);
      });
    });

    group('random pick stability', () {
      testWidgets('presentation is stable across rebuilds (no re-randomization)',
          (tester) async {
        // Pool of many habits -- the picked name must not change across pumps.
        final habits = List.generate(
          10,
          (i) => _habit(name: 'Habit $i', alwaysShown: false),
        );

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        // Find which habit was picked.
        String? picked;
        for (var i = 0; i < 10; i++) {
          if (tester.any(find.text('Habit $i'))) {
            picked = 'Habit $i';
            break;
          }
        }
        expect(picked, isNotNull, reason: 'a habit should be visible');

        // Pump again to simulate a countdown tick rebuild.
        await tester.pump();

        // Same habit should still be shown.
        expect(find.text(picked!), findsOneWidget);
      });
    });
  });
}
