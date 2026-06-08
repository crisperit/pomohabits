import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:taskodoro/app/router.dart';
import 'package:taskodoro/core/preferences/preferences_providers.dart';
import 'package:taskodoro/core/supabase/auth_providers.dart';
import 'package:taskodoro/data/task.dart';
import 'package:taskodoro/features/tasks/presentation/add_task_page.dart';
import 'package:taskodoro/features/tasks/tasks_controller.dart';
import 'package:taskodoro/l10n/app_localizations.dart';

import '../../helpers/stub_filter_builder.dart';

// ---------------------------------------------------------------------------
// Test harness helpers
// ---------------------------------------------------------------------------

/// Pumps [AddTaskPage] inside a minimal GoRouter so `context.pop()` has a
/// destination. Uses [MaterialApp.router] with a two-route stack:
/// [routeTasks] (bottom) -> [routeAddTask] (top).
///
/// Pass [existingTasks] to pre-seed [tasksListProvider] with synchronous data
/// (e.g. for duplicate-check and valid-submit tests).
Future<void> _pumpAddTaskPage(
  WidgetTester tester, {
  required _StubClient stubClient,
  List<Task>? existingTasks,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final overrides = [
    supabaseClientProvider.overrideWithValue(stubClient),
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (existingTasks != null)
      tasksListProvider.overrideWith((_) async => existingTasks),
  ];

  final router = GoRouter(
    initialLocation: routeTasks,
    routes: [
      GoRoute(
        path: routeTasks,
        builder: (context, _) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: routeAddTask,
        builder: (context, _) => const AddTaskPage(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();

  unawaited(router.push(routeAddTask));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AddTaskPage', () {
    testWidgets('empty name blocks submit and shows required error',
        (tester) async {
      final stub = _StubClient();
      await _pumpAddTaskPage(tester, stubClient: stub);

      // Submit with empty name.
      await tester.tap(find.byKey(const ValueKey('addTaskSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a task name.'), findsOneWidget);
      // RPC was not called.
      expect(stub.lastRpcFn, isNull);
    });

    testWidgets('whitespace-only name blocks submit and shows required error',
        (tester) async {
      final stub = _StubClient();
      await _pumpAddTaskPage(tester, stubClient: stub);

      await tester.enterText(
        find.byKey(const ValueKey('taskNameField')),
        '   ',
      );
      await tester.tap(find.byKey(const ValueKey('addTaskSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a task name.'), findsOneWidget);
      expect(stub.lastRpcFn, isNull);
    });

    testWidgets('name longer than 200 chars is rejected with too-long error',
        (tester) async {
      final stub = _StubClient();
      await _pumpAddTaskPage(tester, stubClient: stub, existingTasks: []);

      // 201 'a' characters -- exceeds the 200-char limit.
      await tester.enterText(
        find.byKey(const ValueKey('taskNameField')),
        'a' * 201,
      );
      await tester.tap(find.byKey(const ValueKey('addTaskSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Name must be 200 characters or fewer.'), findsOneWidget);
      expect(stub.lastRpcFn, isNull);
    });

    testWidgets('duplicate name (case-insensitive) is rejected client-side',
        (tester) async {
      final stub = _StubClient();
      // Override with synchronous data so the validator can read the list.
      final existing = [
        Task(
          id: 'id-1',
          name: 'Drink water',
          category: TaskCategory.daily,
          applicableBreakWindow: TaskBreakWindow.both,
          alwaysShown: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      await _pumpAddTaskPage(
        tester,
        stubClient: stub,
        existingTasks: existing,
      );

      // Pre-warm the provider so its future resolves before the validator runs.
      // Without this, the first read inside the validator sees AsyncLoading and
      // .value is null, so the duplicate branch is skipped.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AddTaskPage)),
      );
      await container.read(tasksListProvider.future);
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('taskNameField')),
        'drink water',
      );
      await tester.tap(find.byKey(const ValueKey('addTaskSubmitButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('A task with this name already exists.'),
        findsOneWidget,
      );
      expect(stub.lastRpcFn, isNull);
    });

    testWidgets(
        'valid submit calls rpc add_task with correct p_-prefixed params',
        (tester) async {
      final stub = _StubClient(
        rpcResult: {
          'id': 'new-id',
          'name': 'Drink water',
          'category': 'daily',
          'applicable_break_window': 'both',
          'always_shown': false,
          'icon': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      );
      await _pumpAddTaskPage(tester, stubClient: stub, existingTasks: []);

      await tester.enterText(
        find.byKey(const ValueKey('taskNameField')),
        'Drink water',
      );

      // Category defaults to daily, break window defaults to both,
      // always-shown defaults to false, icon defaults to null --
      // so no interaction needed.

      await tester.tap(find.byKey(const ValueKey('addTaskSubmitButton')));
      await tester.pumpAndSettle();

      expect(stub.lastRpcFn, 'add_task');
      expect(stub.lastRpcParams, {
        'p_name': 'Drink water',
        'p_category': 'daily',
        'p_applicable_break_window': 'both',
        'p_always_shown': false,
        'p_icon': null,
      });
    });

    testWidgets('emoji entered in icon field is forwarded as p_icon',
        (tester) async {
      final stub = _StubClient(
        rpcResult: {
          'id': 'new-id',
          'name': 'Stretch',
          'category': 'daily',
          'applicable_break_window': 'both',
          'always_shown': false,
          'icon': '\u{1F3CB}',
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      );
      await _pumpAddTaskPage(tester, stubClient: stub, existingTasks: []);

      await tester.enterText(
        find.byKey(const ValueKey('taskNameField')),
        'Stretch',
      );
      await tester.enterText(
        find.byKey(const ValueKey('taskIconField')),
        '\u{1F3CB}',
      );

      await tester.tap(find.byKey(const ValueKey('addTaskSubmitButton')));
      await tester.pumpAndSettle();

      expect(stub.lastRpcFn, 'add_task');
      expect(stub.lastRpcParams!['p_icon'], '\u{1F3CB}');
    });

    testWidgets('icon field longer than one grapheme blocks submit',
        (tester) async {
      final stub = _StubClient();
      await _pumpAddTaskPage(tester, stubClient: stub, existingTasks: []);

      await tester.enterText(
        find.byKey(const ValueKey('taskNameField')),
        'Stretch',
      );
      await tester.enterText(
        find.byKey(const ValueKey('taskIconField')),
        '\u{1F3CB}\u{1F3CB}',
      );
      await tester.tap(find.byKey(const ValueKey('addTaskSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Enter one emoji or leave empty.'), findsOneWidget);
      expect(stub.lastRpcFn, isNull);
    });

    testWidgets('stubbed PostgrestException surfaces inline in _ErrorSlot',
        (tester) async {
      final stub = _StubClient(
        rpcError: const PostgrestException(message: 'rpc failed'),
      );
      await _pumpAddTaskPage(tester, stubClient: stub, existingTasks: []);

      await tester.enterText(
        find.byKey(const ValueKey('taskNameField')),
        'Some task',
      );
      await tester.tap(find.byKey(const ValueKey('addTaskSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('rpc failed'), findsOneWidget);
    });

    testWidgets(
        'submit button shows spinner and is disabled while call is in flight',
        (tester) async {
      final completer = Completer<Map<String, dynamic>>();
      final stub = _StubClient(rpcCompleter: completer);
      await _pumpAddTaskPage(tester, stubClient: stub, existingTasks: []);

      await tester.enterText(
        find.byKey(const ValueKey('taskNameField')),
        'Drink water',
      );

      // Tap submit - do NOT settle; the stub is gated by the completer.
      await tester.tap(find.byKey(const ValueKey('addTaskSubmitButton')));
      await tester.pump();

      // Spinner is visible.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Button is disabled (onPressed is null).
      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('addTaskSubmitButton')),
      );
      expect(button.onPressed, isNull);

      // Complete the in-flight call so the post-await context.pop() runs
      // and teardown is clean.
      completer.complete({
        'id': 'x',
        'name': 'Drink water',
        'category': 'daily',
        'applicable_break_window': 'both',
        'always_shown': false,
        'icon': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      await tester.pumpAndSettle();
    });
  });
}

// ---------------------------------------------------------------------------
// Hand-rolled stubs - no mocking library; StubFilterBuilder from
// test/helpers/stub_filter_builder.dart.
// ---------------------------------------------------------------------------

class _StubClient implements SupabaseClient {
  _StubClient({
    this.rpcResult,
    this.rpcError,
    this.rpcCompleter,
  });

  final dynamic rpcResult;
  final PostgrestException? rpcError;

  /// When set, rpc waits for this completer - used to hold the call in-flight.
  final Completer<Map<String, dynamic>>? rpcCompleter;

  String? lastRpcFn;
  Map<String, dynamic>? lastRpcParams;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    get = false,
  }) {
    lastRpcFn = fn;
    lastRpcParams = params;
    if (rpcCompleter != null) {
      return StubFilterBuilder<T>(
        rpcCompleter!.future.then((v) => v as T),
      );
    }
    if (rpcError != null) {
      return StubFilterBuilder<T>(Future<T>.error(rpcError!));
    }
    return StubFilterBuilder<T>(Future<T>.value(rpcResult as T));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
