import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:taskodoro/core/supabase/auth_providers.dart';
import 'package:taskodoro/data/task.dart';
import 'package:taskodoro/features/tasks/tasks_controller.dart';

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

/// Minimal fake builder that delegates `then` to an inner future and routes
/// everything else through noSuchMethod. This satisfies the static type
/// PostgrestFilterBuilder that SupabaseClient.rpc returns, which Dart
/// would otherwise fail to downcast from a plain Future.
class _StubFilterBuilder<T> implements PostgrestFilterBuilder<T> {
  _StubFilterBuilder(this._future);
  final Future<T> _future;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) =>
      _future.then(onValue, onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
      return _StubFilterBuilder<T>(Future<T>.error(rpcError!));
    }
    return _StubFilterBuilder<T>(Future<T>.value(rpcResult as T));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
