import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/core/time/timezone_providers.dart';
import 'package:pomohabits/data/habit.dart';
import 'package:pomohabits/data/habits_repository.dart';
import 'package:pomohabits/features/habits/presentation/habits_page.dart';
import 'package:pomohabits/features/habits/habits_controller.dart';
import 'package:pomohabits/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test harness helpers
// ---------------------------------------------------------------------------

/// Pumps [HabitsPage] in a minimal [MaterialApp] with full l10n + Riverpod.
Future<void> _pumpHabitsPage(
  WidgetTester tester, {
  required AsyncValue<List<Habit>> habitsValue,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitsListProvider.overrideWith((ref) async {
          final value = habitsValue;
          if (value is AsyncData<List<Habit>>) return value.value;
          if (value is AsyncError<List<Habit>>) throw value.error;
          // loading: never-completing future via Completer (no Timer)
          return Completer<List<Habit>>().future;
        }),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HabitsPage(),
      ),
    ),
  );
  await tester.pump();
}

/// Pumps [HabitsPage] with a custom [HabitsController] override in addition
/// to the standard habitsListProvider override. Used for tests that need to
/// inspect controller interactions (e.g. deleteHabit).
Future<void> _pumpHabitsPageWithController(
  WidgetTester tester, {
  required List<Habit> habits,
  required HabitsController controller,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitsListProvider.overrideWith((_) async => habits),
        sharedPreferencesProvider.overrideWithValue(prefs),
        habitsControllerProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HabitsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HabitsPage', () {
    testWidgets('shows spinner while loading', (tester) async {
      final completer = Completer<List<Habit>>();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      addTearDown(() {
        if (!completer.isCompleted) completer.complete(<Habit>[]);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsListProvider.overrideWith((_) => completer.future),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HabitsPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty message when habit list is empty', (tester) async {
      await _pumpHabitsPage(
        tester,
        habitsValue: const AsyncData([]),
      );
      await tester.pumpAndSettle();

      expect(find.text('No habits yet.'), findsOneWidget);
    });

    testWidgets('shows error message when loading fails', (tester) async {
      await _pumpHabitsPage(
        tester,
        habitsValue: AsyncError(Exception('boom'), StackTrace.empty),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load habits.'), findsOneWidget);
    });

    testWidgets('renders a tile for each habit in the list', (tester) async {
      final habits = [
        Habit(
          id: 'id-1',
          name: 'Drink water',
          category: HabitCategory.daily,
          applicableBreakWindow: HabitBreakWindow.both,
          alwaysShown: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        Habit(
          id: 'id-2',
          name: '10 pushups',
          category: HabitCategory.unlimited,
          applicableBreakWindow: HabitBreakWindow.short,
          alwaysShown: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpHabitsPage(
        tester,
        habitsValue: AsyncData(habits),
      );
      await tester.pumpAndSettle();

      expect(find.text('Drink water'), findsOneWidget);
      expect(find.text('10 pushups'), findsOneWidget);
      expect(find.text('Daily - Both'), findsOneWidget);
      expect(find.text('Unlimited - Short'), findsOneWidget);
    });

    testWidgets('refresh action exists in AppBar', (tester) async {
      await _pumpHabitsPage(
        tester,
        habitsValue: const AsyncData([]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('Add FAB exists', (tester) async {
      await _pumpHabitsPage(
        tester,
        habitsValue: const AsyncData([]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('habit with icon renders emoji in leading slot', (tester) async {
      const emoji = '\u{1F3CB}';
      final habits = [
        Habit(
          id: 'id-1',
          name: 'Lift weights',
          category: HabitCategory.daily,
          applicableBreakWindow: HabitBreakWindow.both,
          alwaysShown: false,
          icon: emoji,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpHabitsPage(tester, habitsValue: AsyncData(habits));
      await tester.pumpAndSettle();

      // The emoji should appear as a Text widget in the leading slot.
      expect(find.text(emoji), findsOneWidget);
      // The Material fallback icons should not be present.
      expect(find.byIcon(Icons.push_pin), findsNothing);
      expect(find.byIcon(Icons.task_alt), findsNothing);
    });

    testWidgets('habit without icon shows Material fallback icon',
        (tester) async {
      final habits = [
        Habit(
          id: 'id-1',
          name: 'Drink water',
          category: HabitCategory.daily,
          applicableBreakWindow: HabitBreakWindow.both,
          alwaysShown: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        Habit(
          id: 'id-2',
          name: '10 pushups',
          category: HabitCategory.unlimited,
          applicableBreakWindow: HabitBreakWindow.short,
          alwaysShown: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpHabitsPage(tester, habitsValue: AsyncData(habits));
      await tester.pumpAndSettle();

      // alwaysShown habit gets pin icon, non-always-shown gets task_alt.
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.task_alt), findsOneWidget);
    });

    testWidgets('tapping refresh re-fetches habits', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var fetchCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsRepositoryProvider.overrideWith(
              (ref) => _CountingRepository(onFetch: () => ++fetchCount),
            ),
            localTimezoneProvider.overrideWith((ref) async => 'UTC'),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HabitsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fetchCount, 1);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(fetchCount, 2);
    });

    // -----------------------------------------------------------------------
    // Grouped list tests
    // -----------------------------------------------------------------------

    testWidgets('renders Always shown and Randomized section headers',
        (tester) async {
      final habits = [
        Habit(
          id: 'id-1',
          name: 'Drink water',
          category: HabitCategory.daily,
          applicableBreakWindow: HabitBreakWindow.both,
          alwaysShown: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        Habit(
          id: 'id-2',
          name: '10 pushups',
          category: HabitCategory.unlimited,
          applicableBreakWindow: HabitBreakWindow.short,
          alwaysShown: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpHabitsPage(tester, habitsValue: AsyncData(habits));
      await tester.pumpAndSettle();

      expect(find.text('Always shown'), findsOneWidget);
      expect(find.text('Randomized'), findsOneWidget);
    });

    testWidgets(
        'alwaysShown habit in Always shown section, randomized in Randomized',
        (tester) async {
      final habits = [
        Habit(
          id: 'id-1',
          name: 'Drink water',
          category: HabitCategory.daily,
          applicableBreakWindow: HabitBreakWindow.both,
          alwaysShown: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        Habit(
          id: 'id-2',
          name: '10 pushups',
          category: HabitCategory.unlimited,
          applicableBreakWindow: HabitBreakWindow.short,
          alwaysShown: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpHabitsPage(tester, habitsValue: AsyncData(habits));
      await tester.pumpAndSettle();

      // Both names visible, headers in correct positions.
      expect(find.text('Drink water'), findsOneWidget);
      expect(find.text('10 pushups'), findsOneWidget);

      // 'Always shown' header appears before 'Randomized' in the list.
      final alwaysPos = tester.getTopLeft(find.text('Always shown')).dy;
      final randomPos = tester.getTopLeft(find.text('Randomized')).dy;
      expect(alwaysPos, lessThan(randomPos));

      // 'Drink water' (alwaysShown) appears before 'Randomized' header.
      final drinkPos = tester.getTopLeft(find.text('Drink water')).dy;
      expect(drinkPos, lessThan(randomPos));

      // '10 pushups' (randomized) appears after 'Randomized' header.
      final pushupsPos = tester.getTopLeft(find.text('10 pushups')).dy;
      expect(pushupsPos, greaterThan(randomPos));
    });

    testWidgets('only Always shown header when all habits are alwaysShown',
        (tester) async {
      final habits = [
        Habit(
          id: 'id-1',
          name: 'Drink water',
          category: HabitCategory.daily,
          applicableBreakWindow: HabitBreakWindow.both,
          alwaysShown: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpHabitsPage(tester, habitsValue: AsyncData(habits));
      await tester.pumpAndSettle();

      expect(find.text('Always shown'), findsOneWidget);
      expect(find.text('Randomized'), findsNothing);
    });

    testWidgets('only Randomized header when no habits are alwaysShown',
        (tester) async {
      final habits = [
        Habit(
          id: 'id-1',
          name: '10 pushups',
          category: HabitCategory.unlimited,
          applicableBreakWindow: HabitBreakWindow.short,
          alwaysShown: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpHabitsPage(tester, habitsValue: AsyncData(habits));
      await tester.pumpAndSettle();

      expect(find.text('Always shown'), findsNothing);
      expect(find.text('Randomized'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Overflow menu tests
    // -----------------------------------------------------------------------

    testWidgets('overflow menu shows Edit and Delete items', (tester) async {
      final habits = [
        Habit(
          id: 'id-1',
          name: 'Drink water',
          category: HabitCategory.daily,
          applicableBreakWindow: HabitBreakWindow.both,
          alwaysShown: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpHabitsPage(tester, habitsValue: AsyncData(habits));
      await tester.pumpAndSettle();

      // Open the PopupMenuButton on the habit tile.
      // Use the unparameterized type: the widget is PopupMenuButton<_HabitAction>
      // where _HabitAction is private, so PopupMenuButton<dynamic> won't match.
      await tester.tap(find.byWidgetPredicate(
        (w) => w is PopupMenuButton,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('confirming delete calls deleteHabit on the controller',
        (tester) async {
      final habit = Habit(
        id: 'habit-99',
        name: 'Drink water',
        category: HabitCategory.daily,
        applicableBreakWindow: HabitBreakWindow.both,
        alwaysShown: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final stubController = _StubHabitsController();

      await _pumpHabitsPageWithController(
        tester,
        habits: [habit],
        controller: stubController,
      );

      // Open the overflow menu.
      await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
      await tester.pumpAndSettle();

      // Tap Delete in the overflow menu.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm dialog is visible.
      expect(find.text('Delete habit?'), findsOneWidget);

      // Tap the confirm Delete button inside the dialog.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(stubController.deletedId, 'habit-99');
    });
  });
}

// ---------------------------------------------------------------------------
// Fake repository for the refresh test (no mock library).
// ---------------------------------------------------------------------------

/// A [HabitsRepository] subclass that counts [fetchHabits] calls.
/// Passes a no-op stub client to super; overrides both methods so
/// [_client] is never accessed.
class _CountingRepository extends HabitsRepository {
  _CountingRepository({required this.onFetch})
      : super(_NullClient());

  final int Function() onFetch;

  @override
  Future<List<Habit>> fetchHabits({String timezone = 'UTC'}) async {
    onFetch();
    return [];
  }

  @override
  Future<Habit> addHabit({
    required String name,
    required HabitCategory category,
    required HabitBreakWindow applicableBreakWindow,
    required bool alwaysShown,
    String? icon,
  }) =>
      throw UnimplementedError('addHabit not used in refresh test');
}

/// Minimal [SupabaseClient] stub - all methods throw via [noSuchMethod].
class _NullClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Stub HabitsController for delete interaction tests.
// ---------------------------------------------------------------------------

/// Extends [HabitsController] and records the id passed to [deleteHabit].
/// Returns true so the page proceeds to show the snackbar.
class _StubHabitsController extends HabitsController {
  String? deletedId;

  @override
  Future<bool> deleteHabit(String id) async {
    deletedId = id;
    return true;
  }
}
