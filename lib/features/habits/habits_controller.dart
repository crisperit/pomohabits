import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/timezone_providers.dart';
import '../../data/habit.dart';
import '../../data/habits_repository.dart';

class HabitsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns the created [Habit] on success, or null if the call failed
  /// (state will be [AsyncError] in that case).
  Future<Habit?> addHabit({
    required String name,
    required HabitCategory category,
    required HabitBreakWindow applicableBreakWindow,
    required bool alwaysShown,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard<Habit>(
      () => ref.read(habitsRepositoryProvider).addHabit(
            name: name,
            category: category,
            applicableBreakWindow: applicableBreakWindow,
            alwaysShown: alwaysShown,
            icon: icon,
          ),
    );
    state = result.whenData((_) {});
    return result.value;
  }

  /// Returns the updated [Habit] on success, or null if the call failed
  /// (state will be [AsyncError] in that case).
  Future<Habit?> updateHabit({
    required String id,
    required String name,
    required HabitCategory category,
    required HabitBreakWindow applicableBreakWindow,
    required bool alwaysShown,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard<Habit>(
      () => ref.read(habitsRepositoryProvider).updateHabit(
            id: id,
            name: name,
            category: category,
            applicableBreakWindow: applicableBreakWindow,
            alwaysShown: alwaysShown,
            icon: icon,
          ),
    );
    state = result.whenData((_) {});
    return result.value;
  }

  /// Returns true if the delete succeeded, false if it failed
  /// (state will be [AsyncError] on failure).
  Future<bool> deleteHabit(String id) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard<void>(
      () => ref.read(habitsRepositoryProvider).deleteHabit(id),
    );
    state = result.whenData((_) {});
    return !result.hasError;
  }
}

final habitsControllerProvider =
    AsyncNotifierProvider<HabitsController, void>(HabitsController.new);

final habitsListProvider = FutureProvider<List<Habit>>((ref) async {
  final tz = await ref.watch(localTimezoneProvider.future);
  return ref.watch(habitsRepositoryProvider).fetchHabits(timezone: tz);
});
