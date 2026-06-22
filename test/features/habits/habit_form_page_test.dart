import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/app/router.dart';
import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/core/supabase/auth_providers.dart';
import 'package:pomohabits/data/habit.dart';
import 'package:pomohabits/features/habits/presentation/habit_form_page.dart';
import 'package:pomohabits/features/habits/habits_controller.dart';
import 'package:pomohabits/l10n/app_localizations.dart';

import '../../helpers/stub_filter_builder.dart';

// ---------------------------------------------------------------------------
// Test harness helpers
// ---------------------------------------------------------------------------

/// Pumps [HabitFormPage] inside a minimal GoRouter so `context.pop()` has a
/// destination.
///
/// Pass [habit] to pump in edit mode; omit (null) for add mode.
/// Pass [existingHabits] to pre-seed [habitsListProvider] with synchronous
/// data (e.g. for duplicate-check and valid-submit tests).
Future<void> _pumpHabitFormPage(
  WidgetTester tester, {
  required _StubClient stubClient,
  Habit? habit,
  List<Habit>? existingHabits,
  Size size = const Size(800, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final overrides = [
    supabaseClientProvider.overrideWithValue(stubClient),
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (existingHabits != null)
      habitsListProvider.overrideWith((_) async => existingHabits),
  ];

  final router = GoRouter(
    initialLocation: routeHabits,
    routes: [
      GoRoute(
        path: routeHabits,
        builder: (context, _) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: routeAddHabit,
        builder: (context, _) => HabitFormPage(habit: habit),
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

  unawaited(router.push(routeAddHabit));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Add mode tests
  // ---------------------------------------------------------------------------
  group('HabitFormPage – add mode', () {
    testWidgets('empty name blocks submit and shows required error',
        (tester) async {
      final stub = _StubClient();
      await _pumpHabitFormPage(tester, stubClient: stub);

      await tester.tap(find.byKey(const ValueKey('addHabitSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a habit name.'), findsOneWidget);
      expect(stub.lastRpcFn, isNull);
    });

    testWidgets('whitespace-only name blocks submit and shows required error',
        (tester) async {
      final stub = _StubClient();
      await _pumpHabitFormPage(tester, stubClient: stub);

      await tester.enterText(
        find.byKey(const ValueKey('habitNameField')),
        '   ',
      );
      await tester.tap(find.byKey(const ValueKey('addHabitSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a habit name.'), findsOneWidget);
      expect(stub.lastRpcFn, isNull);
    });

    testWidgets('name longer than 200 chars is rejected with too-long error',
        (tester) async {
      final stub = _StubClient();
      await _pumpHabitFormPage(
        tester,
        stubClient: stub,
        existingHabits: [],
      );

      await tester.enterText(
        find.byKey(const ValueKey('habitNameField')),
        'a' * 201,
      );
      await tester.tap(find.byKey(const ValueKey('addHabitSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('Name must be 200 characters or fewer.'), findsOneWidget);
      expect(stub.lastRpcFn, isNull);
    });

    testWidgets('duplicate name (case-insensitive) is rejected client-side',
        (tester) async {
      final stub = _StubClient();
      final existing = [
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

      await _pumpHabitFormPage(
        tester,
        stubClient: stub,
        existingHabits: existing,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HabitFormPage)),
      );
      await container.read(habitsListProvider.future);
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('habitNameField')),
        'drink water',
      );
      await tester.tap(find.byKey(const ValueKey('addHabitSubmitButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('A habit with this name already exists.'),
        findsOneWidget,
      );
      expect(stub.lastRpcFn, isNull);
    });

    testWidgets(
        'valid submit calls rpc add_habit with correct p_-prefixed params',
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
      await _pumpHabitFormPage(
        tester,
        stubClient: stub,
        existingHabits: [],
      );

      await tester.enterText(
        find.byKey(const ValueKey('habitNameField')),
        'Drink water',
      );
      await tester.tap(find.byKey(const ValueKey('addHabitSubmitButton')));
      await tester.pumpAndSettle();

      expect(stub.lastRpcFn, 'add_habit');
      expect(stub.lastRpcParams, {
        'p_name': 'Drink water',
        'p_category': 'daily',
        'p_applicable_break_window': 'both',
        'p_always_shown': false,
        'p_icon': null,
      });
    });

    testWidgets('tapping habitIconButton opens the emoji picker sheet',
        (tester) async {
      final stub = _StubClient();
      await _pumpHabitFormPage(tester, stubClient: stub);

      await tester.tap(find.byKey(const ValueKey('habitIconButton')));
      await tester.pumpAndSettle();

      expect(find.byType(EmojiPicker), findsOneWidget);
    });

    testWidgets('selecting an emoji in the picker forwards it as p_icon',
        (tester) async {
      const selectedEmoji = '\u{1F642}'; // slightly smiling face
      final stub = _StubClient(
        rpcResult: {
          'id': 'new-id',
          'name': 'Stretch',
          'category': 'daily',
          'applicable_break_window': 'both',
          'always_shown': false,
          'icon': selectedEmoji,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      );
      await _pumpHabitFormPage(tester, stubClient: stub, existingHabits: []);

      // Open picker.
      await tester.tap(find.byKey(const ValueKey('habitIconButton')));
      await tester.pumpAndSettle();

      // Switch to search view via the search icon in the BottomActionBar.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Type to filter to a single known emoji, more deterministic than
      // scrolling the full grid.
      final searchField = find.descendant(
        of: find.byType(EmojiPicker),
        matching: find.byType(TextField),
      );
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'slightly smiling');
      await tester.pumpAndSettle();

      // Tap the emoji in the search results.
      final emojiInResults = find.text(selectedEmoji).hitTestable();
      expect(emojiInResults, findsAtLeastNWidgets(1));
      await tester.tap(emojiInResults.first);
      await tester.pumpAndSettle();

      // Bottom sheet should be dismissed and icon button should show the emoji.
      expect(find.byType(EmojiPicker), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('habitIconButton')),
          matching: find.text(selectedEmoji),
        ),
        findsOneWidget,
      );

      // Fill name and submit.
      await tester.enterText(
        find.byKey(const ValueKey('habitNameField')),
        'Stretch',
      );
      await tester.tap(find.byKey(const ValueKey('addHabitSubmitButton')));
      await tester.pumpAndSettle();

      expect(stub.lastRpcFn, 'add_habit');
      expect(stub.lastRpcParams!['p_icon'], selectedEmoji);
    });

    testWidgets('stubbed PostgrestException surfaces inline in _ErrorSlot',
        (tester) async {
      final stub = _StubClient(
        rpcError: const PostgrestException(message: 'rpc failed'),
      );
      await _pumpHabitFormPage(
        tester,
        stubClient: stub,
        existingHabits: [],
      );

      await tester.enterText(
        find.byKey(const ValueKey('habitNameField')),
        'Some habit',
      );
      await tester.tap(find.byKey(const ValueKey('addHabitSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('rpc failed'), findsOneWidget);
    });

    testWidgets(
        'submit button shows spinner and is disabled while call is in flight',
        (tester) async {
      final completer = Completer<Map<String, dynamic>>();
      final stub = _StubClient(rpcCompleter: completer);
      await _pumpHabitFormPage(
        tester,
        stubClient: stub,
        existingHabits: [],
      );

      await tester.enterText(
        find.byKey(const ValueKey('habitNameField')),
        'Drink water',
      );

      await tester.tap(find.byKey(const ValueKey('addHabitSubmitButton')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('addHabitSubmitButton')),
      );
      expect(button.onPressed, isNull);

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

  // ---------------------------------------------------------------------------
  // Edit mode tests
  // ---------------------------------------------------------------------------
  group('HabitFormPage – edit mode', () {
    final existingHabit = Habit(
      id: 'habit-42',
      name: 'Drink water',
      category: HabitCategory.daily,
      applicableBreakWindow: HabitBreakWindow.both,
      alwaysShown: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    testWidgets('pre-fills name field from the passed habit', (tester) async {
      final stub = _StubClient();
      await _pumpHabitFormPage(
        tester,
        stubClient: stub,
        habit: existingHabit,
        existingHabits: [existingHabit],
      );

      final nameField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('habitNameField')),
          matching: find.byType(EditableText),
        ),
      );
      expect(nameField.controller.text, 'Drink water');
    });

    testWidgets(
        "allows the habit's own unchanged name (self excluded from duplicate check)",
        (tester) async {
      final stub = _StubClient(
        rpcResult: {
          'id': existingHabit.id,
          'name': existingHabit.name,
          'category': 'daily',
          'applicable_break_window': 'both',
          'always_shown': true,
          'icon': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      );
      // existingHabits contains the habit being edited; self must be excluded.
      await _pumpHabitFormPage(
        tester,
        stubClient: stub,
        habit: existingHabit,
        existingHabits: [existingHabit],
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HabitFormPage)),
      );
      await container.read(habitsListProvider.future);
      await tester.pump();

      // Name is already pre-filled; just submit without changing it.
      await tester.tap(find.byKey(const ValueKey('saveHabitSubmitButton')));
      await tester.pumpAndSettle();

      // No duplicate error shown; the RPC was called.
      expect(
        find.text('A habit with this name already exists.'),
        findsNothing,
      );
      expect(stub.lastRpcFn, 'update_habit');
    });

    testWidgets(
        'submit calls rpc update_habit with correct p_-prefixed params',
        (tester) async {
      final stub = _StubClient(
        rpcResult: {
          'id': existingHabit.id,
          'name': 'Drink sparkling water',
          'category': 'daily',
          'applicable_break_window': 'both',
          'always_shown': true,
          'icon': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      );
      await _pumpHabitFormPage(
        tester,
        stubClient: stub,
        habit: existingHabit,
        existingHabits: [],
      );

      // Change the name.
      await tester.enterText(
        find.byKey(const ValueKey('habitNameField')),
        'Drink sparkling water',
      );
      await tester.tap(find.byKey(const ValueKey('saveHabitSubmitButton')));
      await tester.pumpAndSettle();

      expect(stub.lastRpcFn, 'update_habit');
      expect(stub.lastRpcParams!['p_id'], existingHabit.id);
      expect(stub.lastRpcParams!['p_name'], 'Drink sparkling water');
      expect(stub.lastRpcParams!['p_category'], 'daily');
      expect(stub.lastRpcParams!['p_applicable_break_window'], 'both');
      expect(stub.lastRpcParams!['p_always_shown'], true);
      expect(stub.lastRpcParams!['p_icon'], isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Hand-rolled stubs - no mocking library.
// ---------------------------------------------------------------------------

class _StubClient implements SupabaseClient {
  _StubClient({
    this.rpcResult,
    this.rpcError,
    this.rpcCompleter,
  });

  final dynamic rpcResult;
  final PostgrestException? rpcError;
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
