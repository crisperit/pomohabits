import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

final habitsControllerProvider =
    AsyncNotifierProvider<HabitsController, void>(HabitsController.new);

final habitsListProvider = FutureProvider<List<Habit>>(
  (ref) => ref.watch(habitsRepositoryProvider).fetchHabits(),
);
