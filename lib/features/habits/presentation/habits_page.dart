import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../data/habit.dart';
import '../../../l10n/app_localizations.dart';
import '../habits_controller.dart';

class HabitsPage extends ConsumerWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final habitsAsync = ref.watch(habitsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.habitsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.habitsRefreshTooltip,
            onPressed: () => ref.invalidate(habitsListProvider),
          ),
        ],
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.habitsLoadError)),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(child: Text(l10n.habitsEmpty));
          }
          return ListView.builder(
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return ListTile(
                leading: habit.icon != null
                    ? Text(
                        habit.icon!,
                        style: const TextStyle(fontSize: 24),
                      )
                    : habit.alwaysShown
                        ? const Icon(Icons.push_pin)
                        : const Icon(Icons.task_alt),
                title: Text(habit.name),
                subtitle: Text(
                  '${_categoryLabel(l10n, habit.category)} - '
                  '${_breakWindowLabel(l10n, habit.applicableBreakWindow)}',
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(routeAddHabit),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, HabitCategory category) =>
      switch (category) {
        HabitCategory.oneTime => l10n.categoryOneTime,
        HabitCategory.daily => l10n.categoryDaily,
        HabitCategory.unlimited => l10n.categoryUnlimited,
      };

  String _breakWindowLabel(AppLocalizations l10n, HabitBreakWindow window) =>
      switch (window) {
        HabitBreakWindow.short => l10n.breakWindowShort,
        HabitBreakWindow.long => l10n.breakWindowLong,
        HabitBreakWindow.both => l10n.breakWindowBoth,
      };
}
