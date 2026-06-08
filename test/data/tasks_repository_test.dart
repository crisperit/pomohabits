import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:taskodoro/core/supabase/auth_providers.dart';
import 'package:taskodoro/data/task.dart';
import 'package:taskodoro/data/tasks_repository.dart';

import '../helpers/stub_filter_builder.dart';

void main() {
  group('TaskCategory', () {
    test('wire values round-trip for all cases', () {
      expect(TaskCategory.oneTime.wire, 'one_time');
      expect(TaskCategory.daily.wire, 'daily');
      expect(TaskCategory.unlimited.wire, 'unlimited');

      expect(TaskCategory.fromWire('one_time'), TaskCategory.oneTime);
      expect(TaskCategory.fromWire('daily'), TaskCategory.daily);
      expect(TaskCategory.fromWire('unlimited'), TaskCategory.unlimited);
    });

    test('fromWire throws ArgumentError on unknown value', () {
      expect(() => TaskCategory.fromWire('garbage'), throwsArgumentError);
    });
  });

  group('TaskBreakWindow', () {
    test('wire values round-trip for all cases', () {
      expect(TaskBreakWindow.short.wire, 'short');
      expect(TaskBreakWindow.long.wire, 'long');
      expect(TaskBreakWindow.both.wire, 'both');

      expect(TaskBreakWindow.fromWire('short'), TaskBreakWindow.short);
      expect(TaskBreakWindow.fromWire('long'), TaskBreakWindow.long);
      expect(TaskBreakWindow.fromWire('both'), TaskBreakWindow.both);
    });

    test('fromWire throws ArgumentError on unknown value', () {
      expect(() => TaskBreakWindow.fromWire('garbage'), throwsArgumentError);
    });
  });

  group('Task.fromRow', () {
    final baseRow = <String, dynamic>{
      'id': 'abc-123',
      'name': 'Drink water',
      'category': 'daily',
      'applicable_break_window': 'both',
      'always_shown': true,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-02T12:00:00.000Z',
    };

    test('maps all fields correctly', () {
      final task = Task.fromRow(baseRow);

      expect(task.id, 'abc-123');
      expect(task.name, 'Drink water');
      expect(task.category, TaskCategory.daily);
      expect(task.applicableBreakWindow, TaskBreakWindow.both);
      expect(task.alwaysShown, isTrue);
      expect(task.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(task.updatedAt, DateTime.parse('2026-01-02T12:00:00.000Z'));
    });

    test('ignores extra keys completed_today and completed_ever', () {
      final rowWithExtras = {
        ...baseRow,
        'completed_today': true,
        'completed_ever': false,
      };

      expect(() => Task.fromRow(rowWithExtras), returnsNormally);
      final task = Task.fromRow(rowWithExtras);
      expect(task.id, 'abc-123');
    });
  });

  group('TasksRepository', () {
    test('addTask calls rpc with p_-prefixed keys and wire enum values',
        () async {
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

      final task = await container.read(tasksRepositoryProvider).addTask(
            name: 'Drink water',
            category: TaskCategory.daily,
            applicableBreakWindow: TaskBreakWindow.both,
            alwaysShown: true,
          );

      expect(stub.lastRpcFn, 'add_task');
      expect(stub.lastRpcParams, {
        'p_name': 'Drink water',
        'p_category': 'daily',
        'p_applicable_break_window': 'both',
        'p_always_shown': true,
      });
      expect(task.id, 'new-id');
      expect(task.category, TaskCategory.daily);
      expect(task.applicableBreakWindow, TaskBreakWindow.both);
    });

    test('addTask passes correct wire values for one_time + short', () async {
      final stub = _StubClient(
        rpcResult: {
          'id': 'id-2',
          'name': '10 pushups',
          'category': 'one_time',
          'applicable_break_window': 'short',
          'always_shown': false,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      await container.read(tasksRepositoryProvider).addTask(
            name: '10 pushups',
            category: TaskCategory.oneTime,
            applicableBreakWindow: TaskBreakWindow.short,
            alwaysShown: false,
          );

      expect(stub.lastRpcParams!['p_category'], 'one_time');
      expect(stub.lastRpcParams!['p_applicable_break_window'], 'short');
    });

    test('fetchTasks maps a multi-row list_tasks response', () async {
      final stub = _StubClient(
        rpcResult: [
          {
            'id': 'id-1',
            'name': 'Drink water',
            'category': 'daily',
            'applicable_break_window': 'both',
            'always_shown': true,
            'created_at': '2026-01-01T00:00:00.000Z',
            'updated_at': '2026-01-01T00:00:00.000Z',
            'completed_today': false,
            'completed_ever': true,
          },
          {
            'id': 'id-2',
            'name': '10 pushups',
            'category': 'unlimited',
            'applicable_break_window': 'short',
            'always_shown': false,
            'created_at': '2026-01-02T00:00:00.000Z',
            'updated_at': '2026-01-02T00:00:00.000Z',
            'completed_today': true,
            'completed_ever': true,
          },
        ],
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      final tasks = await container.read(tasksRepositoryProvider).fetchTasks();

      expect(stub.lastRpcFn, 'list_tasks');
      expect(tasks.length, 2);
      expect(tasks[0].id, 'id-1');
      expect(tasks[0].category, TaskCategory.daily);
      expect(tasks[1].id, 'id-2');
      expect(tasks[1].category, TaskCategory.unlimited);
    });

    test('fetchTasks propagates PostgrestException without swallowing',
        () async {
      final stub = _StubClient(
        rpcError: const PostgrestException(message: 'db error'),
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(tasksRepositoryProvider).fetchTasks(),
        throwsA(isA<PostgrestException>()),
      );
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
    if (rpcError != null) {
      return StubFilterBuilder<T>(Future<T>.error(rpcError!));
    }
    return StubFilterBuilder<T>(Future<T>.value(rpcResult as T));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
