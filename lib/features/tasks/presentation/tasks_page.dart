import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../data/task.dart';
import '../../../l10n/app_localizations.dart';
import '../tasks_controller.dart';

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tasksAsync = ref.watch(tasksListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tasksTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.tasksRefreshTooltip,
            onPressed: () => ref.invalidate(tasksListProvider),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.tasksLoadError)),
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(child: Text(l10n.tasksEmpty));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                leading: task.icon != null
                    ? Text(
                        task.icon!,
                        style: const TextStyle(fontSize: 24),
                      )
                    : task.alwaysShown
                        ? const Icon(Icons.push_pin)
                        : const Icon(Icons.task_alt),
                title: Text(task.name),
                subtitle: Text(
                  '${_categoryLabel(l10n, task.category)} - '
                  '${_breakWindowLabel(l10n, task.applicableBreakWindow)}',
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(routeAddTask),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, TaskCategory category) =>
      switch (category) {
        TaskCategory.oneTime => l10n.categoryOneTime,
        TaskCategory.daily => l10n.categoryDaily,
        TaskCategory.unlimited => l10n.categoryUnlimited,
      };

  String _breakWindowLabel(AppLocalizations l10n, TaskBreakWindow window) =>
      switch (window) {
        TaskBreakWindow.short => l10n.breakWindowShort,
        TaskBreakWindow.long => l10n.breakWindowLong,
        TaskBreakWindow.both => l10n.breakWindowBoth,
      };
}
