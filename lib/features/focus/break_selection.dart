import 'dart:math';

import '../../data/habit.dart';

/// The result of [selectBreakPresentation]: the ordered list of always-shown
/// eligible habits, an optional single randomized habit from the eligible pool,
/// and a flag indicating whether a built-in suggestion should be shown instead.
class BreakPresentation {
  const BreakPresentation({
    required this.alwaysShownHabits,
    required this.randomizedHabit,
    required this.useBuiltInSuggestion,
  });

  /// Habits that are [Habit.alwaysShown] and eligible for the current break
  /// window, in input order.
  final List<Habit> alwaysShownHabits;

  /// A single habit chosen uniformly at random from the eligible
  /// non-always-shown pool, or `null` when that pool is empty.
  final Habit? randomizedHabit;

  /// `true` when the randomized pool is empty and the UI should fall back to
  /// displaying a built-in suggestion (FR-011 never-blank guarantee).
  final bool useBuiltInSuggestion;
}

/// Returns `true` if [habit] is eligible for display in the current break
/// window described by [isLongBreak].
///
/// Long break: `long` or `both`. Short break: `short` or `both`.
bool _windowMatches(Habit habit, {required bool isLongBreak}) {
  final window = habit.applicableBreakWindow;
  if (isLongBreak) {
    return window == HabitBreakWindow.long || window == HabitBreakWindow.both;
  }
  return window == HabitBreakWindow.short || window == HabitBreakWindow.both;
}

/// Computes the break presentation from [habits] for the current break window.
///
/// - [isLongBreak] distinguishes long-break (`long`/`both`) from short-break
///   (`short`/`both`) eligibility.
/// - [random] is injected so callers can pass a seeded [Random] in tests for
///   deterministic results.
///
/// Always-shown habits ([Habit.alwaysShown] == `true` and window matches) are
/// returned in input order. One habit is picked uniformly at random from the
/// non-always-shown eligible pool; when that pool is empty,
/// [BreakPresentation.useBuiltInSuggestion] is `true` and
/// [BreakPresentation.randomizedHabit] is `null`.
BreakPresentation selectBreakPresentation({
  required List<Habit> habits,
  required bool isLongBreak,
  required Random random,
}) {
  final alwaysShown = <Habit>[];
  final randomPool = <Habit>[];

  for (final habit in habits) {
    if (!_windowMatches(habit, isLongBreak: isLongBreak)) continue;
    if (habit.alwaysShown) {
      alwaysShown.add(habit);
    } else {
      randomPool.add(habit);
    }
  }

  if (randomPool.isEmpty) {
    return BreakPresentation(
      alwaysShownHabits: alwaysShown,
      randomizedHabit: null,
      useBuiltInSuggestion: true,
    );
  }

  final picked = randomPool[random.nextInt(randomPool.length)];
  return BreakPresentation(
    alwaysShownHabits: alwaysShown,
    randomizedHabit: picked,
    useBuiltInSuggestion: false,
  );
}
