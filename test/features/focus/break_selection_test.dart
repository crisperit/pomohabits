import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:pomohabits/data/habit.dart';
import 'package:pomohabits/features/focus/break_selection.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Habit _makeHabit({
  required String id,
  required String name,
  required HabitBreakWindow window,
  required bool alwaysShown,
  HabitCategory category = HabitCategory.daily,
  bool completedToday = false,
  bool completedEver = false,
}) {
  return Habit(
    id: id,
    name: name,
    category: category,
    applicableBreakWindow: window,
    alwaysShown: alwaysShown,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    completedToday: completedToday,
    completedEver: completedEver,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('isHabitEligible: category x completion flag truth table', () {
    test('daily, not completed today, not completed ever: eligible', () {
      final habit = _makeHabit(
        id: 'e1',
        name: 'h',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.daily,
        completedToday: false,
        completedEver: false,
      );
      expect(isHabitEligible(habit), isTrue);
    });

    test('daily, completed today: not eligible', () {
      final habit = _makeHabit(
        id: 'e2',
        name: 'h',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.daily,
        completedToday: true,
        completedEver: false,
      );
      expect(isHabitEligible(habit), isFalse);
    });

    test('daily, completedEver true but not completedToday: eligible (reset semantics)', () {
      final habit = _makeHabit(
        id: 'e3',
        name: 'h',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.daily,
        completedToday: false,
        completedEver: true,
      );
      expect(isHabitEligible(habit), isTrue);
    });

    test('daily, completedToday true AND completedEver true: not eligible', () {
      final habit = _makeHabit(
        id: 'e4',
        name: 'h',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.daily,
        completedToday: true,
        completedEver: true,
      );
      expect(isHabitEligible(habit), isFalse);
    });

    test('oneTime, never completed: eligible', () {
      final habit = _makeHabit(
        id: 'e5',
        name: 'h',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.oneTime,
        completedToday: false,
        completedEver: false,
      );
      expect(isHabitEligible(habit), isTrue);
    });

    test('oneTime, completedToday only (not completedEver): eligible', () {
      final habit = _makeHabit(
        id: 'e6',
        name: 'h',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.oneTime,
        completedToday: true,
        completedEver: false,
      );
      expect(isHabitEligible(habit), isTrue);
    });

    test('oneTime, completedEver true: not eligible', () {
      final habit = _makeHabit(
        id: 'e7',
        name: 'h',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.oneTime,
        completedToday: false,
        completedEver: true,
      );
      expect(isHabitEligible(habit), isFalse);
    });

    test('oneTime, completedToday true AND completedEver true: not eligible', () {
      final habit = _makeHabit(
        id: 'e8',
        name: 'h',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.oneTime,
        completedToday: true,
        completedEver: true,
      );
      expect(isHabitEligible(habit), isFalse);
    });

    test('unlimited, not completed: eligible', () {
      final habit = _makeHabit(
        id: 'e9',
        name: 'h',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.unlimited,
        completedToday: false,
        completedEver: false,
      );
      expect(isHabitEligible(habit), isTrue);
    });

    test('unlimited, completedToday true AND completedEver true: still eligible', () {
      final habit = _makeHabit(
        id: 'e10',
        name: 'h',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.unlimited,
        completedToday: true,
        completedEver: true,
      );
      expect(isHabitEligible(habit), isTrue);
    });
  });

  group('selectBreakPresentation: eligibility filtering', () {
    test('daily completed today is excluded from random pool', () {
      final habit = _makeHabit(
        id: 'f1',
        name: 'Morning run',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.daily,
        completedToday: true,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, isNull);
      expect(result.useBuiltInSuggestion, isTrue);
    });

    test('daily NOT completed today is included in random pool', () {
      final habit = _makeHabit(
        id: 'f2',
        name: 'Morning run',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.daily,
        completedToday: false,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, equals(habit));
      expect(result.useBuiltInSuggestion, isFalse);
    });

    test('daily completedEver but NOT completedToday is included (reset semantics)', () {
      final habit = _makeHabit(
        id: 'f3',
        name: 'Morning run',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.daily,
        completedToday: false,
        completedEver: true,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, equals(habit));
      expect(result.useBuiltInSuggestion, isFalse);
    });

    test('oneTime completedEver is excluded from random pool', () {
      final habit = _makeHabit(
        id: 'f4',
        name: 'Write a letter',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.oneTime,
        completedEver: true,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, isNull);
      expect(result.useBuiltInSuggestion, isTrue);
    });

    test('oneTime never completed is included in random pool', () {
      final habit = _makeHabit(
        id: 'f5',
        name: 'Write a letter',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.oneTime,
        completedEver: false,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, equals(habit));
      expect(result.useBuiltInSuggestion, isFalse);
    });

    test('unlimited with completedToday and completedEver true is still included', () {
      final habit = _makeHabit(
        id: 'f6',
        name: 'Breathe',
        window: HabitBreakWindow.both,
        alwaysShown: false,
        category: HabitCategory.unlimited,
        completedToday: true,
        completedEver: true,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, equals(habit));
      expect(result.useBuiltInSuggestion, isFalse);
    });

    test('completed always-shown daily habit is excluded from alwaysShownHabits', () {
      final completed = _makeHabit(
        id: 'f7',
        name: 'Stretch',
        window: HabitBreakWindow.both,
        alwaysShown: true,
        category: HabitCategory.daily,
        completedToday: true,
      );
      final result = selectBreakPresentation(
        habits: [completed],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.alwaysShownHabits, isEmpty);
      expect(result.randomizedHabit, isNull);
      expect(result.useBuiltInSuggestion, isTrue);
    });

    test('pool where every eligible habit is completed yields useBuiltInSuggestion true', () {
      final habits = [
        _makeHabit(
          id: 'f8a',
          name: 'Pushups',
          window: HabitBreakWindow.both,
          alwaysShown: false,
          category: HabitCategory.daily,
          completedToday: true,
        ),
        _makeHabit(
          id: 'f8b',
          name: 'Sit-ups',
          window: HabitBreakWindow.both,
          alwaysShown: false,
          category: HabitCategory.oneTime,
          completedEver: true,
        ),
      ];
      final result = selectBreakPresentation(
        habits: habits,
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, isNull);
      expect(result.useBuiltInSuggestion, isTrue);
      expect(result.alwaysShownHabits, isEmpty);
    });
  });

  group('selectBreakPresentation: short-break window filtering', () {
    test('includes habits with window=short in a short break', () {
      final habit = _makeHabit(
        id: '1',
        name: 'Pushups',
        window: HabitBreakWindow.short,
        alwaysShown: false,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, equals(habit));
      expect(result.useBuiltInSuggestion, isFalse);
    });

    test('includes habits with window=both in a short break', () {
      final habit = _makeHabit(
        id: '2',
        name: 'Breathe',
        window: HabitBreakWindow.both,
        alwaysShown: false,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, equals(habit));
    });

    test('excludes habits with window=long from a short break', () {
      final habit = _makeHabit(
        id: '3',
        name: 'Long walk',
        window: HabitBreakWindow.long,
        alwaysShown: false,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, isNull);
      expect(result.useBuiltInSuggestion, isTrue);
    });
  });

  group('selectBreakPresentation: long-break window filtering', () {
    test('includes habits with window=long in a long break', () {
      final habit = _makeHabit(
        id: '4',
        name: 'Meditate',
        window: HabitBreakWindow.long,
        alwaysShown: false,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: true,
        random: Random(0),
      );
      expect(result.randomizedHabit, equals(habit));
      expect(result.useBuiltInSuggestion, isFalse);
    });

    test('includes habits with window=both in a long break', () {
      final habit = _makeHabit(
        id: '5',
        name: 'Drink water',
        window: HabitBreakWindow.both,
        alwaysShown: false,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: true,
        random: Random(0),
      );
      expect(result.randomizedHabit, equals(habit));
    });

    test('excludes habits with window=short from a long break', () {
      final habit = _makeHabit(
        id: '6',
        name: 'Pushups',
        window: HabitBreakWindow.short,
        alwaysShown: false,
      );
      final result = selectBreakPresentation(
        habits: [habit],
        isLongBreak: true,
        random: Random(0),
      );
      expect(result.randomizedHabit, isNull);
      expect(result.useBuiltInSuggestion, isTrue);
    });
  });

  group('selectBreakPresentation: always-shown partitioning', () {
    test('always-shown habits appear in alwaysShownHabits, not randomizedHabit',
        () {
      final always = _makeHabit(
        id: 'a1',
        name: 'Stretch',
        window: HabitBreakWindow.both,
        alwaysShown: true,
      );
      final result = selectBreakPresentation(
        habits: [always],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.alwaysShownHabits, contains(always));
      expect(result.randomizedHabit, isNull);
      expect(result.useBuiltInSuggestion, isTrue);
    });

    test(
        'non-always-shown habits go into the random pool, not alwaysShownHabits',
        () {
      final randomHabit = _makeHabit(
        id: 'r1',
        name: 'Pushups',
        window: HabitBreakWindow.both,
        alwaysShown: false,
      );
      final result = selectBreakPresentation(
        habits: [randomHabit],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.alwaysShownHabits, isEmpty);
      expect(result.randomizedHabit, equals(randomHabit));
    });

    test('always-shown habit is never the randomizedHabit in a mixed list', () {
      final always = _makeHabit(
        id: 'a2',
        name: 'Drink water',
        window: HabitBreakWindow.both,
        alwaysShown: true,
      );
      final rand = _makeHabit(
        id: 'r2',
        name: 'Walk',
        window: HabitBreakWindow.both,
        alwaysShown: false,
      );
      final result = selectBreakPresentation(
        habits: [always, rand],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.alwaysShownHabits, equals([always]));
      expect(result.randomizedHabit, equals(rand));
      expect(result.useBuiltInSuggestion, isFalse);
    });

    test('alwaysShownHabits preserves input order', () {
      final h1 = _makeHabit(
        id: 'o1',
        name: 'First',
        window: HabitBreakWindow.both,
        alwaysShown: true,
      );
      final h2 = _makeHabit(
        id: 'o2',
        name: 'Second',
        window: HabitBreakWindow.both,
        alwaysShown: true,
      );
      final h3 = _makeHabit(
        id: 'o3',
        name: 'Third',
        window: HabitBreakWindow.both,
        alwaysShown: true,
      );
      final result = selectBreakPresentation(
        habits: [h1, h2, h3],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.alwaysShownHabits, equals([h1, h2, h3]));
    });
  });

  group('selectBreakPresentation: seeded random pick', () {
    test('seeded Random picks the deterministically expected element', () {
      final pool = [
        _makeHabit(
          id: 'p1',
          name: 'A',
          window: HabitBreakWindow.both,
          alwaysShown: false,
        ),
        _makeHabit(
          id: 'p2',
          name: 'B',
          window: HabitBreakWindow.both,
          alwaysShown: false,
        ),
        _makeHabit(
          id: 'p3',
          name: 'C',
          window: HabitBreakWindow.both,
          alwaysShown: false,
        ),
      ];

      // Determine what index seed=7 picks from a 3-element list.
      final expectedIndex = Random(7).nextInt(3);
      final expected = pool[expectedIndex];

      final result = selectBreakPresentation(
        habits: pool,
        isLongBreak: false,
        random: Random(7),
      );
      expect(result.randomizedHabit, equals(expected));
    });

    test('same seed always yields the same randomizedHabit', () {
      final pool = List.generate(
        5,
        (i) => _makeHabit(
          id: 'q$i',
          name: 'Habit $i',
          window: HabitBreakWindow.short,
          alwaysShown: false,
        ),
      );

      final r1 = selectBreakPresentation(
        habits: pool,
        isLongBreak: false,
        random: Random(99),
      );
      final r2 = selectBreakPresentation(
        habits: pool,
        isLongBreak: false,
        random: Random(99),
      );
      expect(r1.randomizedHabit, equals(r2.randomizedHabit));
    });
  });

  group('selectBreakPresentation: empty-pool fallback', () {
    test('empty habit list gives useBuiltInSuggestion true, no randomized habit',
        () {
      final result = selectBreakPresentation(
        habits: [],
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, isNull);
      expect(result.useBuiltInSuggestion, isTrue);
      expect(result.alwaysShownHabits, isEmpty);
    });

    test(
        'all habits always-shown gives empty random pool and useBuiltInSuggestion true',
        () {
      final habits = [
        _makeHabit(
          id: 's1',
          name: 'Stretch',
          window: HabitBreakWindow.both,
          alwaysShown: true,
        ),
        _makeHabit(
          id: 's2',
          name: 'Hydrate',
          window: HabitBreakWindow.both,
          alwaysShown: true,
        ),
      ];
      final result = selectBreakPresentation(
        habits: habits,
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, isNull);
      expect(result.useBuiltInSuggestion, isTrue);
      expect(result.alwaysShownHabits.length, 2);
    });

    test('no habits match the break window gives useBuiltInSuggestion true',
        () {
      // All habits are long-window only; we query for a short break.
      final habits = [
        _makeHabit(
          id: 'w1',
          name: 'Long walk',
          window: HabitBreakWindow.long,
          alwaysShown: false,
        ),
      ];
      final result = selectBreakPresentation(
        habits: habits,
        isLongBreak: false,
        random: Random(0),
      );
      expect(result.randomizedHabit, isNull);
      expect(result.useBuiltInSuggestion, isTrue);
      expect(result.alwaysShownHabits, isEmpty);
    });
  });
}
