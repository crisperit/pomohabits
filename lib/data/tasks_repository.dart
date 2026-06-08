import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/auth_providers.dart';
import 'task.dart';

const _rpcAddTask = 'add_task';
const _rpcListTasks = 'list_tasks';

class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

  Future<Task> addTask({
    required String name,
    required TaskCategory category,
    required TaskBreakWindow applicableBreakWindow,
    required bool alwaysShown,
  }) async {
    final response = await _client.rpc(
      _rpcAddTask,
      params: {
        'p_name': name,
        'p_category': category.wire,
        'p_applicable_break_window': applicableBreakWindow.wire,
        'p_always_shown': alwaysShown,
      },
    );
    return Task.fromRow(response as Map<String, dynamic>);
  }

  Future<List<Task>> fetchTasks() async {
    final response = await _client.rpc(_rpcListTasks);
    return (response as List)
        .map((r) => Task.fromRow(r as Map<String, dynamic>))
        .toList();
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.watch(supabaseClientProvider)),
);
