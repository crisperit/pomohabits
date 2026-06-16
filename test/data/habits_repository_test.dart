import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/core/supabase/auth_providers.dart';
import 'package:pomohabits/data/habit.dart';
import 'package:pomohabits/data/habits_repository.dart';

import '../helpers/stub_filter_builder.dart';

void main() {
  group('HabitCategory', () {
    test('wire values round-trip for all cases', () {
      expect(HabitCategory.oneTime.wire, 'one_time');
      expect(HabitCategory.daily.wire, 'daily');
      expect(HabitCategory.unlimited.wire, 'unlimited');

      expect(HabitCategory.fromWire('one_time'), HabitCategory.oneTime);
      expect(HabitCategory.fromWire('daily'), HabitCategory.daily);
      expect(HabitCategory.fromWire('unlimited'), HabitCategory.unlimited);
    });

    test('fromWire throws ArgumentError on unknown value', () {
      expect(() => HabitCategory.fromWire('garbage'), throwsArgumentError);
    });
  });

  group('HabitBreakWindow', () {
    test('wire values round-trip for all cases', () {
      expect(HabitBreakWindow.short.wire, 'short');
      expect(HabitBreakWindow.long.wire, 'long');
      expect(HabitBreakWindow.both.wire, 'both');

      expect(HabitBreakWindow.fromWire('short'), HabitBreakWindow.short);
      expect(HabitBreakWindow.fromWire('long'), HabitBreakWindow.long);
      expect(HabitBreakWindow.fromWire('both'), HabitBreakWindow.both);
    });

    test('fromWire throws ArgumentError on unknown value', () {
      expect(() => HabitBreakWindow.fromWire('garbage'), throwsArgumentError);
    });
  });

  group('Habit.fromRow', () {
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
      final habit = Habit.fromRow(baseRow);

      expect(habit.id, 'abc-123');
      expect(habit.name, 'Drink water');
      expect(habit.category, HabitCategory.daily);
      expect(habit.applicableBreakWindow, HabitBreakWindow.both);
      expect(habit.alwaysShown, isTrue);
      expect(habit.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(habit.updatedAt, DateTime.parse('2026-01-02T12:00:00.000Z'));
    });

    test('icon is null when key is absent', () {
      final habit = Habit.fromRow(baseRow);
      expect(habit.icon, isNull);
    });

    test('icon is null when key is present and null', () {
      final habit = Habit.fromRow({...baseRow, 'icon': null});
      expect(habit.icon, isNull);
    });

    test('icon equals the string when present', () {
      final habit = Habit.fromRow({...baseRow, 'icon': '🔥'});
      expect(habit.icon, '🔥');
    });

    test('ignores extra keys completed_today and completed_ever', () {
      final rowWithExtras = {
        ...baseRow,
        'completed_today': true,
        'completed_ever': false,
      };

      expect(() => Habit.fromRow(rowWithExtras), returnsNormally);
      final habit = Habit.fromRow(rowWithExtras);
      expect(habit.id, 'abc-123');
    });
  });

  group('HabitsRepository', () {
    test('addHabit calls rpc with p_-prefixed keys and wire enum values',
        () async {
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

      final habit = await container.read(habitsRepositoryProvider).addHabit(
            name: 'Drink water',
            category: HabitCategory.daily,
            applicableBreakWindow: HabitBreakWindow.both,
            alwaysShown: true,
          );

      expect(stub.lastRpcFn, 'add_habit');
      expect(stub.lastRpcParams, {
        'p_name': 'Drink water',
        'p_category': 'daily',
        'p_applicable_break_window': 'both',
        'p_always_shown': true,
        'p_icon': null,
      });
      expect(habit.id, 'new-id');
      expect(habit.category, HabitCategory.daily);
      expect(habit.applicableBreakWindow, HabitBreakWindow.both);
    });

    test('addHabit passes correct wire values for one_time + short', () async {
      final stub = _StubClient(
        rpcResult: {
          'id': 'id-2',
          'name': '10 pushups',
          'category': 'one_time',
          'applicable_break_window': 'short',
          'always_shown': false,
          'icon': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      await container.read(habitsRepositoryProvider).addHabit(
            name: '10 pushups',
            category: HabitCategory.oneTime,
            applicableBreakWindow: HabitBreakWindow.short,
            alwaysShown: false,
          );

      expect(stub.lastRpcParams!['p_category'], 'one_time');
      expect(stub.lastRpcParams!['p_applicable_break_window'], 'short');
    });

    test('addHabit forwards icon as p_icon in rpc params', () async {
      final stub = _StubClient(
        rpcResult: {
          'id': 'id-3',
          'name': 'Stretch',
          'category': 'daily',
          'applicable_break_window': 'both',
          'always_shown': false,
          'icon': '🔥',
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      await container.read(habitsRepositoryProvider).addHabit(
            name: 'Stretch',
            category: HabitCategory.daily,
            applicableBreakWindow: HabitBreakWindow.both,
            alwaysShown: false,
            icon: '🔥',
          );

      expect(stub.lastRpcParams!['p_icon'], '🔥');
    });

    test('fetchHabits maps a multi-row list_habits response', () async {
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

      final habits =
          await container.read(habitsRepositoryProvider).fetchHabits();

      expect(stub.lastRpcFn, 'list_habits');
      expect(habits.length, 2);
      expect(habits[0].id, 'id-1');
      expect(habits[0].category, HabitCategory.daily);
      expect(habits[1].id, 'id-2');
      expect(habits[1].category, HabitCategory.unlimited);
    });

    test('fetchHabits propagates PostgrestException without swallowing',
        () async {
      final stub = _StubClient(
        rpcError: const PostgrestException(message: 'db error'),
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWith((ref) => stub)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(habitsRepositoryProvider).fetchHabits(),
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
