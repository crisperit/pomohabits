import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task.dart';
import '../../data/tasks_repository.dart';

class TasksController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns the created [Task] on success, or null if the call failed
  /// (state will be [AsyncError] in that case).
  Future<Task?> addTask({
    required String name,
    required TaskCategory category,
    required TaskBreakWindow applicableBreakWindow,
    required bool alwaysShown,
    String? icon,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard<Task>(
      () => ref.read(tasksRepositoryProvider).addTask(
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

final tasksControllerProvider =
    AsyncNotifierProvider<TasksController, void>(TasksController.new);

final tasksListProvider = FutureProvider<List<Task>>(
  (ref) => ref.watch(tasksRepositoryProvider).fetchTasks(),
);
