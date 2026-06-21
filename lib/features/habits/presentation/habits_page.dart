import 'dart:async';

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

          final alwaysShown = habits.where((h) => h.alwaysShown).toList();
          final randomized = habits.where((h) => !h.alwaysShown).toList();

          return ListView(
            children: [
              if (alwaysShown.isNotEmpty) ...[
                _SectionHeader(label: l10n.habitsGroupAlwaysShown),
                for (final habit in alwaysShown)
                  _HabitTile(habit: habit, l10n: l10n),
              ],
              if (randomized.isNotEmpty) ...[
                _SectionHeader(label: l10n.habitsGroupRandomized),
                for (final habit in randomized)
                  _HabitTile(habit: habit, l10n: l10n),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(context.push(routeAddHabit)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Habit tile with overflow menu
// ---------------------------------------------------------------------------

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.habit, required this.l10n});

  final Habit habit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onTap: () => unawaited(context.push(routeEditHabit, extra: habit)),
      trailing: PopupMenuButton<_HabitAction>(
        onSelected: (action) {
          switch (action) {
            case _HabitAction.edit:
              unawaited(context.push(routeEditHabit, extra: habit));
            case _HabitAction.delete:
              unawaited(_confirmDelete(context, ref));
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _HabitAction.edit,
            child: Text(l10n.habitEditAction),
          ),
          PopupMenuItem(
            value: _HabitAction.delete,
            child: Text(l10n.habitDeleteAction),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(habitsControllerProvider.notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.habitDeleteConfirmTitle),
        content: Text(l10n.habitDeleteConfirmBody(habit.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.habitDeleteConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.habitDeleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deleted = await controller.deleteHabit(habit.id);
    if (deleted) {
      ref.invalidate(habitsListProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.habitDeletedSuccess)),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.habitDeleteError)),
      );
    }
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

enum _HabitAction { edit, delete }
