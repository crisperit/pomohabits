import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/data/task.dart';
import 'package:pomohabits/data/tasks_repository.dart';
import 'package:pomohabits/features/tasks/presentation/tasks_page.dart';
import 'package:pomohabits/features/tasks/tasks_controller.dart';
import 'package:pomohabits/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test harness helpers
// ---------------------------------------------------------------------------

/// Pumps [TasksPage] in a minimal [MaterialApp] with full l10n + Riverpod.
Future<void> _pumpTasksPage(
  WidgetTester tester, {
  required AsyncValue<List<Task>> tasksValue,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tasksListProvider.overrideWith((ref) async {
          final value = tasksValue;
          if (value is AsyncData<List<Task>>) return value.value;
          if (value is AsyncError<List<Task>>) throw value.error;
          // loading: never-completing future via Completer (no Timer)
          return Completer<List<Task>>().future;
        }),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TasksPage(),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TasksPage', () {
    testWidgets('shows spinner while loading', (tester) async {
      final completer = Completer<List<Task>>();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      addTearDown(() {
        if (!completer.isCompleted) completer.complete(<Task>[]);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksListProvider.overrideWith((_) => completer.future),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TasksPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty message when task list is empty', (tester) async {
      await _pumpTasksPage(
        tester,
        tasksValue: const AsyncData([]),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tasks yet.'), findsOneWidget);
    });

    testWidgets('shows error message when loading fails', (tester) async {
      await _pumpTasksPage(
        tester,
        tasksValue: AsyncError(Exception('boom'), StackTrace.empty),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load tasks.'), findsOneWidget);
    });

    testWidgets('renders a tile for each task in the list', (tester) async {
      final tasks = [
        Task(
          id: 'id-1',
          name: 'Drink water',
          category: TaskCategory.daily,
          applicableBreakWindow: TaskBreakWindow.both,
          alwaysShown: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        Task(
          id: 'id-2',
          name: '10 pushups',
          category: TaskCategory.unlimited,
          applicableBreakWindow: TaskBreakWindow.short,
          alwaysShown: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpTasksPage(
        tester,
        tasksValue: AsyncData(tasks),
      );
      await tester.pumpAndSettle();

      expect(find.text('Drink water'), findsOneWidget);
      expect(find.text('10 pushups'), findsOneWidget);
      expect(find.text('Daily - Both'), findsOneWidget);
      expect(find.text('Unlimited - Short'), findsOneWidget);
    });

    testWidgets('refresh action exists in AppBar', (tester) async {
      await _pumpTasksPage(
        tester,
        tasksValue: const AsyncData([]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('Add FAB exists', (tester) async {
      await _pumpTasksPage(
        tester,
        tasksValue: const AsyncData([]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('task with icon renders emoji in leading slot', (tester) async {
      const emoji = '\u{1F3CB}';
      final tasks = [
        Task(
          id: 'id-1',
          name: 'Lift weights',
          category: TaskCategory.daily,
          applicableBreakWindow: TaskBreakWindow.both,
          alwaysShown: false,
          icon: emoji,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpTasksPage(tester, tasksValue: AsyncData(tasks));
      await tester.pumpAndSettle();

      // The emoji should appear as a Text widget in the leading slot.
      expect(find.text(emoji), findsOneWidget);
      // The Material fallback icons should not be present.
      expect(find.byIcon(Icons.push_pin), findsNothing);
      expect(find.byIcon(Icons.task_alt), findsNothing);
    });

    testWidgets('task without icon shows Material fallback icon',
        (tester) async {
      final tasks = [
        Task(
          id: 'id-1',
          name: 'Drink water',
          category: TaskCategory.daily,
          applicableBreakWindow: TaskBreakWindow.both,
          alwaysShown: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        Task(
          id: 'id-2',
          name: '10 pushups',
          category: TaskCategory.unlimited,
          applicableBreakWindow: TaskBreakWindow.short,
          alwaysShown: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpTasksPage(tester, tasksValue: AsyncData(tasks));
      await tester.pumpAndSettle();

      // alwaysShown task gets pin icon, non-always-shown gets task_alt.
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.task_alt), findsOneWidget);
    });

    testWidgets('tapping refresh re-fetches tasks', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var fetchCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksRepositoryProvider.overrideWith(
              (ref) => _CountingRepository(onFetch: () => ++fetchCount),
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TasksPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fetchCount, 1);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(fetchCount, 2);
    });
  });
}

// ---------------------------------------------------------------------------
// Fake repository for the refresh test (no mock library).
// ---------------------------------------------------------------------------

/// A [TasksRepository] subclass that counts [fetchTasks] calls.
/// Passes a no-op stub client to super; overrides both methods so
/// [_client] is never accessed.
class _CountingRepository extends TasksRepository {
  _CountingRepository({required this.onFetch})
      : super(_NullClient());

  final int Function() onFetch;

  @override
  Future<List<Task>> fetchTasks() async {
    onFetch();
    return [];
  }

  @override
  Future<Task> addTask({
    required String name,
    required TaskCategory category,
    required TaskBreakWindow applicableBreakWindow,
    required bool alwaysShown,
    String? icon,
  }) =>
      throw UnimplementedError('addTask not used in refresh test');
}

/// Minimal [SupabaseClient] stub - all methods throw via [noSuchMethod].
class _NullClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
