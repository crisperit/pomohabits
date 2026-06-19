import 'dart:math';

import '../../data/habit.dart';

/// The result of [selectBreakPresentation]: the ordered list of always-shown
/// eligible habits, an optional single randomized habit from the eligible pool,
/// the full eligible random pool (for Roll-again), and a flag indicating
/// whether a built-in suggestion should be shown instead.
class BreakPresentation {
  const BreakPresentation({
    required this.alwaysShownHabits,
    required this.randomizedHabit,
    required this.useBuiltInSuggestion,
    required this.eligibleRandomPool,
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

  /// The full set of eligible non-always-shown habits for the current break
  /// window, regardless of which one was initially picked.
  ///
  /// Callers (e.g. Roll-again) can use this pool to draw a different habit via
  /// [rollRandomizedHabit] without re-running the always-shown filter. When
  /// [randomizedHabit] is non-null it is an element of this list. When
  /// [useBuiltInSuggestion] is `true` this list is empty.
  final List<Habit> eligibleRandomPool;
}

/// Returns `true` when [habit] may be shown on a break according to its
/// completion state and category rules:
///
/// - [HabitCategory.oneTime]: eligible only when the habit has never been
///   completed (`!habit.completedEver`).
/// - [HabitCategory.daily]: eligible only when the habit has not been
///   completed today (`!habit.completedToday`); `completedEver` is irrelevant
///   because the daily flag resets at local midnight.
/// - [HabitCategory.unlimited]: always eligible regardless of completion
///   state.
bool isHabitEligible(Habit habit) => switch (habit.category) {
      HabitCategory.oneTime => !habit.completedEver,
      HabitCategory.daily => !habit.completedToday,
      HabitCategory.unlimited => true,
    };

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
    if (!isHabitEligible(habit)) continue;
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
      eligibleRandomPool: randomPool,
    );
  }

  final picked = randomPool[random.nextInt(randomPool.length)];
  return BreakPresentation(
    alwaysShownHabits: alwaysShown,
    randomizedHabit: picked,
    useBuiltInSuggestion: false,
    eligibleRandomPool: randomPool,
  );
}

/// Picks a different eligible habit than [current] from [pool], drawn
/// uniformly at random.
///
/// The rolled-out habit ([current]) stays in [pool] - it is excluded from
/// this draw only, so it can reappear on a subsequent call. The draw is
/// performed over `pool.where((h) => h.id != current.id)`.
///
/// Returns [current] unchanged when no other candidate exists (i.e. [pool]
/// contains only [current], or [pool] has length ≤ 1). When [pool] is empty,
/// [current] is returned as-is: [current] is not itself a pool member in that
/// case, so callers should only invoke this function when a randomized habit is
/// already being shown.
///
/// [pool] is never mutated. [random] is injected for deterministic tests,
/// matching the seam used by [selectBreakPresentation].
Habit rollRandomizedHabit({
  required List<Habit> pool,
  required Habit current,
  required Random random,
}) {
  final candidates = pool.where((h) => h.id != current.id).toList();
  if (candidates.isEmpty) return current;
  return candidates[random.nextInt(candidates.length)];
}
