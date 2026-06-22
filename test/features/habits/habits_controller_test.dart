import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/core/supabase/auth_providers.dart';
import 'package:pomohabits/data/habit.dart';
import 'package:pomohabits/features/habits/habits_controller.dart';

import '../../helpers/stub_filter_builder.dart';

void main() {
  group('HabitsController', () {
    test('addHabit returns Habit on success and state has no error', () async {
      final stub = _StubClient(
        rpcResult: {
          'id': 'new-id',
          'name': 'Drink water',
          'category': 'daily',
          'applicable_break_window': 'both',
          'always_shown': true,
          'icon': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      final habit = await container
          .read(habitsControllerProvider.notifier)
          .addHabit(
            name: 'Drink water',
            category: HabitCategory.daily,
            applicableBreakWindow: HabitBreakWindow.both,
            alwaysShown: true,
          );

      expect(habit, isNotNull);
      expect(habit!.id, 'new-id');
      expect(habit.name, 'Drink water');
      expect(container.read(habitsControllerProvider).hasError, isFalse);
    });

    test(
        'addHabit returns null and lands error in state when repository throws',
        () async {
      final stub = _StubClient(
        rpcError: const PostgrestException(message: 'insert failed'),
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      final habit = await container
          .read(habitsControllerProvider.notifier)
          .addHabit(
            name: 'Drink water',
            category: HabitCategory.daily,
            applicableBreakWindow: HabitBreakWindow.both,
            alwaysShown: true,
          );

      expect(habit, isNull);
      final state = container.read(habitsControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error as PostgrestException).message, 'insert failed');
    });

    test('updateHabit returns Habit on success and state has no error',
        () async {
      final stub = _StubClient(
        rpcResult: {
          'id': 'existing-id',
          'name': 'Updated name',
          'category': 'daily',
          'applicable_break_window': 'both',
          'always_shown': false,
          'icon': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-06-19T00:00:00.000Z',
        },
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      final habit = await container
          .read(habitsControllerProvider.notifier)
          .updateHabit(
            id: 'existing-id',
            name: 'Updated name',
            category: HabitCategory.daily,
            applicableBreakWindow: HabitBreakWindow.both,
            alwaysShown: false,
          );

      expect(habit, isNotNull);
      expect(habit!.id, 'existing-id');
      expect(habit.name, 'Updated name');
      expect(container.read(habitsControllerProvider).hasError, isFalse);
    });

    test(
        'updateHabit returns null and lands error in state when repository throws',
        () async {
      final stub = _StubClient(
        rpcError: const PostgrestException(message: 'update failed'),
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      final habit = await container
          .read(habitsControllerProvider.notifier)
          .updateHabit(
            id: 'some-id',
            name: 'x',
            category: HabitCategory.daily,
            applicableBreakWindow: HabitBreakWindow.both,
            alwaysShown: false,
          );

      expect(habit, isNull);
      final state = container.read(habitsControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error as PostgrestException).message, 'update failed');
    });

    test('deleteHabit returns true on success and state has no error',
        () async {
      final stub = _StubClient(rpcResult: null);
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(habitsControllerProvider.notifier)
          .deleteHabit('del-id');

      expect(success, isTrue);
      expect(container.read(habitsControllerProvider).hasError, isFalse);
    });

    test(
        'deleteHabit returns false and lands error in state when repository throws',
        () async {
      final stub = _StubClient(
        rpcError: const PostgrestException(message: 'delete failed'),
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(habitsControllerProvider.notifier)
          .deleteHabit('some-id');

      expect(success, isFalse);
      final state = container.read(habitsControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error as PostgrestException).message, 'delete failed');
    });
  });
}

// ---------------------------------------------------------------------------
// Hand-rolled stubs - no mocking library, mirrors auth_controller_test.dart
// ---------------------------------------------------------------------------

class _StubClient implements SupabaseClient {
  _StubClient({this.rpcResult, this.rpcError});

  final dynamic rpcResult;
  final PostgrestException? rpcError;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    get = false,
  }) {
    if (rpcError != null) {
      return StubFilterBuilder<T>(Future<T>.error(rpcError!));
    }
    return StubFilterBuilder<T>(Future<T>.value(rpcResult as T));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
