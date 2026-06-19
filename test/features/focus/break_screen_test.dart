import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/data/habit.dart';
import 'package:pomohabits/data/habits_repository.dart';
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

/// Minimal [SupabaseClient] stub: all methods throw via [noSuchMethod].
class _NullClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub [HabitsRepository] for mark-complete tests.
///
/// Records the ids passed to [completeHabit]. When [throwOnComplete] is true,
/// every [completeHabit] call throws a [PostgrestException] to simulate a
/// server failure. When [blockOn] is provided, [completeHabit] awaits that
/// completer before recording the id -- use this to hold the call in-flight
/// so the widget tree can be inspected while the async operation is pending.
class _StubHabitsRepository extends HabitsRepository {
  _StubHabitsRepository({
    this.throwOnComplete = false,
    this.blockOn,
  }) : super(_NullClient());

  final bool throwOnComplete;
  final Completer<void>? blockOn;
  final List<String> completedIds = [];

  @override
  Future<void> completeHabit(String habitId) async {
    if (throwOnComplete) {
      throw const PostgrestException(message: 'simulated failure');
    }
    if (blockOn != null) {
      await blockOn!.future;
    }
    completedIds.add(habitId);
  }

  @override
  Future<List<Habit>> fetchHabits({String timezone = 'UTC'}) async => [];

  @override
  Future<Habit> addHabit({
    required String name,
    required HabitCategory category,
    required HabitBreakWindow applicableBreakWindow,
    required bool alwaysShown,
    String? icon,
  }) =>
      throw UnimplementedError('addHabit not used in break_screen tests');
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
///
/// Pass [stubRepo] to also override [habitsRepositoryProvider] for mark-complete
/// tests.
Future<_FakeFocusController> _pump(
  WidgetTester tester, {
  required FocusSessionState sessionState,
  required AsyncValue<List<Habit>> habitsValue,
  bool isLongBreak = false,
  Completer<List<Habit>>? loadingCompleter,
  _StubHabitsRepository? stubRepo,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fakeFullscreen = _FakeFullscreenController();
  final fakeFocus = _FakeFocusController(sessionState);

  final overrides = [
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
    if (stubRepo != null)
      habitsRepositoryProvider.overrideWithValue(stubRepo),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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

    // -------------------------------------------------------------------------
    // Mark-complete affordance
    // -------------------------------------------------------------------------

    group('mark-complete: default state shows action control', () {
      testWidgets('each habit tile renders check_circle_outline in default state',
          (tester) async {
        final habits = [
          _habit(name: 'Drink water', alwaysShown: true),
          _habit(name: 'Stretch', alwaysShown: false),
        ];
        final stub = _StubHabitsRepository();

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
          stubRepo: stub,
        );
        await tester.pumpAndSettle();

        // Both tiles should show the outline check icon (mark-complete button).
        expect(
          find.byIcon(Icons.check_circle_outline),
          findsNWidgets(2),
        );
        // No filled check yet.
        expect(find.byIcon(Icons.check_circle), findsNothing);
      });
    });

    group('mark-complete: happy path', () {
      testWidgets(
          'tapping mark-complete calls completeHabit and tile shows done state',
          (tester) async {
        final habits = [
          _habit(name: 'Drink water', alwaysShown: true),
        ];
        final stub = _StubHabitsRepository();

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
          stubRepo: stub,
        );
        await tester.pumpAndSettle();

        // Tap the mark-complete button on the tile.
        await tester.tap(find.byIcon(Icons.check_circle_outline));
        await tester.pumpAndSettle();

        // completeHabit should have been called with the habit's id.
        expect(stub.completedIds, contains('Drink water'));

        // The tile should now show the filled check (completed state).
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        // The outline icon should be gone (button removed when completed).
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);

        // Title should have strike-through decoration; verify via widget tree.
        final titleWidget = tester.widget<Text>(find.text('Drink water'));
        expect(
          titleWidget.style?.decoration,
          TextDecoration.lineThrough,
        );
      });

      testWidgets('double-tap guard: second tap does not call completeHabit again',
          (tester) async {
        // Use a Completer to hold completeHabit in-flight so the widget tree
        // can be inspected while the async call is still pending. This lets
        // us verify the guard fires before the server round-trip finishes.
        final completer = Completer<void>();
        final habits = [
          _habit(name: 'Stretch', alwaysShown: true),
        ];
        final stub = _StubHabitsRepository(blockOn: completer);

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
          stubRepo: stub,
        );
        await tester.pumpAndSettle();

        // First tap -- triggers _markComplete, which calls setState optimistically
        // (adds the id to _completedHabitIds) then awaits completeHabit (blocked).
        await tester.tap(find.byIcon(Icons.check_circle_outline));

        // Single frame: lets the synchronous setState run so the tile rebuilds
        // into its completed state, swapping out the mark-complete button.
        await tester.pump();

        // The guard is enforced at two levels:
        //   1. UI-level: the optimistic setState immediately replaces the
        //      mark-complete button with the completed tile, so the button no
        //      longer exists in the widget tree. A second tap cannot reach the
        //      handler because the target widget is structurally absent.
        //   2. Code-level: _markComplete has an early-return if the id is
        //      already in _completedHabitIds (_completedHabitIds.contains(id)).
        //      This is the backstop for any code path that bypasses the UI.
        //
        // We verify level 1 here: check_circle_outline is gone and the
        // completed state (check_circle) is in its place.
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        // No second tester.tap is attempted: tester.tap on a finder that
        // matches zero widgets throws "could not find any matching widgets"
        // regardless of warnIfMissed (that flag only suppresses the warning
        // when a widget IS found but the hit-test misses). The structural
        // absence proven above IS the guard test: the button simply does not
        // exist for a second tap to land on.

        // Unblock the repository and let everything settle.
        completer.complete();
        await tester.pumpAndSettle();

        // The repository must have been called exactly once: the second tap
        // could not reach the handler because the button was already gone.
        expect(stub.completedIds.length, 1);
        expect(stub.completedIds, contains('Stretch'));
      });
    });

    group('mark-complete: failure path', () {
      testWidgets(
          'failing completeHabit reverts tile to default state and shows snackbar',
          (tester) async {
        final habits = [
          _habit(name: 'Meditate', alwaysShown: true),
        ];
        final stub = _StubHabitsRepository(throwOnComplete: true);

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
          stubRepo: stub,
        );
        await tester.pumpAndSettle();

        // Tap the mark-complete button.
        await tester.tap(find.byIcon(Icons.check_circle_outline));
        await tester.pumpAndSettle();

        // The tile should have reverted - outline icon back, no filled check.
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsNothing);

        // A SnackBar with the error text should be visible.
        expect(
          find.text("Couldn't save that. Try again."),
          findsOneWidget,
        );
      });
    });

    // -------------------------------------------------------------------------
    // Roll-again affordance
    // -------------------------------------------------------------------------

    group('roll-again', () {
      testWidgets(
          'with 2+ eligible randomized habits: control is present and enabled',
          (tester) async {
        // Build a pool large enough that a swap is virtually certain.
        final poolNames = ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'];
        final habits = poolNames
            .map((n) => _habit(name: n, alwaysShown: false))
            .toList();

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        // Roll-again button must exist.
        final rollFinder = find.widgetWithText(TextButton, 'Roll again');
        expect(rollFinder, findsOneWidget);

        // Button must be enabled (onPressed is non-null).
        final btn = tester.widget<TextButton>(rollFinder);
        expect(btn.onPressed, isNotNull);
      });

      testWidgets(
          'with 2+ eligible randomized habits: tapping roll-again keeps exactly '
          'one randomized habit tile visible and it remains a pool member',
          (tester) async {
        final poolNames = ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'];
        final habits = poolNames
            .map((n) => _habit(name: n, alwaysShown: false))
            .toList();

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        // Determine which habit was initially shown.
        String? initialName;
        for (final n in poolNames) {
          if (tester.any(find.text(n))) {
            initialName = n;
            break;
          }
        }
        expect(initialName, isNotNull,
            reason: 'one pool habit should be visible before rolling');

        // Tap Roll-again.
        await tester.tap(find.widgetWithText(TextButton, 'Roll again'));
        await tester.pumpAndSettle();

        // Exactly one pool habit should still be visible.
        final visibleAfter =
            poolNames.where((n) => tester.any(find.text(n))).toList();
        expect(visibleAfter, hasLength(1),
            reason: 'exactly one randomized tile should show after a roll');

        // The visible habit must be one of the pool names.
        expect(poolNames, contains(visibleAfter.first));
      });

      testWidgets(
          'with 2+ eligible randomized habits: always-shown section and '
          'countdown are untouched after a roll', (tester) async {
        final habits = [
          _habit(name: 'Always One', alwaysShown: true),
          _habit(name: 'Pool A', alwaysShown: false),
          _habit(name: 'Pool B', alwaysShown: false),
        ];

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        // Confirm always-shown is present before roll.
        expect(find.text('Always One'), findsOneWidget);
        expect(find.text('04:00'), findsOneWidget);

        // Tap Roll-again.
        await tester.tap(find.widgetWithText(TextButton, 'Roll again'));
        await tester.pumpAndSettle();

        // Always-shown and countdown must be unchanged.
        expect(find.text('Always One'), findsOneWidget);
        expect(find.text('04:00'), findsOneWidget);
      });

      testWidgets(
          'with exactly one eligible randomized habit: control is present but '
          'disabled', (tester) async {
        final habits = [
          _habit(name: 'Only Pick', alwaysShown: false),
        ];

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        // Roll-again button must exist.
        final rollFinder = find.widgetWithText(TextButton, 'Roll again');
        expect(rollFinder, findsOneWidget);

        // Button must be disabled (onPressed is null).
        final btn = tester.widget<TextButton>(rollFinder);
        expect(btn.onPressed, isNull);
      });

      testWidgets(
          'with empty pool (suggestion shown): Roll-again control is absent',
          (tester) async {
        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: const AsyncData([]),
        );
        await tester.pumpAndSettle();

        // Suggestion shown, no Roll-again button.
        expect(find.text('Try this'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Roll again'), findsNothing);
      });

      testWidgets(
          'with all-always-shown habits (empty random pool): Roll-again absent',
          (tester) async {
        final habits = [
          _habit(name: 'Always A', alwaysShown: true),
          _habit(name: 'Always B', alwaysShown: true),
        ];

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextButton, 'Roll again'), findsNothing);
      });

      testWidgets(
          'second roll moves away from first rolled pick, not just from '
          'the original (roll-again passes current displayed habit as current)',
          (tester) async {
        // Pool of 5: all non-always-shown, window both. With 5 candidates,
        // rollRandomizedHabit always has 4 alternatives, so each tap is
        // guaranteed to produce a name different from the immediately preceding
        // visible pick.
        final poolNames = ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'];
        final habits =
            poolNames.map((n) => _habit(name: n, alwaysShown: false)).toList();

        await _pump(
          tester,
          sessionState: _shortBreakState,
          habitsValue: AsyncData(habits),
        );
        await tester.pumpAndSettle();

        // Read the initially visible randomized pick.
        String? name1;
        for (final n in poolNames) {
          if (tester.any(find.text(n))) {
            name1 = n;
            break;
          }
        }
        expect(name1, isNotNull, reason: 'one pool habit should be visible initially');

        // First Roll-again tap.
        await tester.tap(find.widgetWithText(TextButton, 'Roll again'));
        await tester.pumpAndSettle();

        String? name2;
        for (final n in poolNames) {
          if (tester.any(find.text(n))) {
            name2 = n;
            break;
          }
        }
        expect(name2, isNotNull, reason: 'one pool habit should be visible after first roll');
        // Must differ from the pick that was showing before this tap.
        expect(name2, isNot(name1),
            reason: 'first roll should move away from the initial pick');

        // Second Roll-again tap.
        await tester.tap(find.widgetWithText(TextButton, 'Roll again'));
        await tester.pumpAndSettle();

        String? name3;
        for (final n in poolNames) {
          if (tester.any(find.text(n))) {
            name3 = n;
            break;
          }
        }
        expect(name3, isNotNull, reason: 'one pool habit should be visible after second roll');
        // Must differ from the pick that was showing before this tap (name2),
        // not just from the original pick. This guards that _rolledHabit is
        // passed as current to rollRandomizedHabit on the second call.
        expect(name3, isNot(name2),
            reason: 'second roll should move away from the first rolled pick');
      });
    });
  });
}
