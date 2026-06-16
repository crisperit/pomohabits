import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/core/supabase/auth_providers.dart';
import 'package:pomohabits/data/task.dart';
import 'package:pomohabits/features/tasks/tasks_controller.dart';

import '../../helpers/stub_filter_builder.dart';

void main() {
  group('TasksController', () {
    test('addTask returns Task on success and state has no error', () async {
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

      final task = await container
          .read(tasksControllerProvider.notifier)
          .addTask(
            name: 'Drink water',
            category: TaskCategory.daily,
            applicableBreakWindow: TaskBreakWindow.both,
            alwaysShown: true,
          );

      expect(task, isNotNull);
      expect(task!.id, 'new-id');
      expect(task.name, 'Drink water');
      expect(container.read(tasksControllerProvider).hasError, isFalse);
    });

    test('addTask returns null and lands error in state when repository throws',
        () async {
      final stub = _StubClient(
        rpcError: const PostgrestException(message: 'insert failed'),
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      final task = await container
          .read(tasksControllerProvider.notifier)
          .addTask(
            name: 'Drink water',
            category: TaskCategory.daily,
            applicableBreakWindow: TaskBreakWindow.both,
            alwaysShown: true,
          );

      expect(task, isNull);
      final state = container.read(tasksControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error as PostgrestException).message, 'insert failed');
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
