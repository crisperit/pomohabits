import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/task.dart';
import '../../../l10n/app_localizations.dart';
import '../tasks_controller.dart';

class AddTaskPage extends ConsumerStatefulWidget {
  const AddTaskPage({super.key});

  @override
  ConsumerState<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends ConsumerState<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  TaskCategory _category = TaskCategory.daily;
  TaskBreakWindow _breakWindow = TaskBreakWindow.both;
  bool _alwaysShown = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _errorMessage(AppLocalizations l10n, AsyncValue<void> state) {
    if (!state.hasError) return null;
    final err = state.error;
    if (err is PostgrestException) return err.message;
    if (err is AuthException) return err.message;
    return l10n.taskErrorUnexpected;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final created = await ref
        .read(tasksControllerProvider.notifier)
        .addTask(
          name: name,
          category: _category,
          applicableBreakWindow: _breakWindow,
          alwaysShown: _alwaysShown,
        );
    if (!mounted) return;

    if (created != null) {
      ref.invalidate(tasksListProvider);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.taskAddedSuccess)),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tasksState = ref.watch(tasksControllerProvider);
    final isLoading = tasksState.isLoading;
    final errorMsg = _errorMessage(l10n, tasksState);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addTaskTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const ValueKey('taskNameField'),
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l10n.taskNameLabel),
                      maxLength: 200,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        final trimmed = v?.trim() ?? '';
                        if (trimmed.isEmpty) return l10n.taskErrorNameRequired;
                        if (trimmed.length > 200) return l10n.taskErrorNameTooLong;
                        final existing = ref.read(tasksListProvider).value;
                        if (existing != null) {
                          final lower = trimmed.toLowerCase();
                          final isDuplicate = existing.any(
                            (t) => t.name.trim().toLowerCase() == lower,
                          );
                          if (isDuplicate) return l10n.taskErrorNameDuplicate;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownMenu<TaskCategory>(
                      initialSelection: _category,
                      label: Text(l10n.taskCategoryLabel),
                      expandedInsets: EdgeInsets.zero,
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          value: TaskCategory.oneTime,
                          label: l10n.categoryOneTime,
                        ),
                        DropdownMenuEntry(
                          value: TaskCategory.daily,
                          label: l10n.categoryDaily,
                        ),
                        DropdownMenuEntry(
                          value: TaskCategory.unlimited,
                          label: l10n.categoryUnlimited,
                        ),
                      ],
                      onSelected: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownMenu<TaskBreakWindow>(
                      initialSelection: _breakWindow,
                      label: Text(l10n.breakWindowLabel),
                      expandedInsets: EdgeInsets.zero,
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          value: TaskBreakWindow.short,
                          label: l10n.breakWindowShort,
                        ),
                        DropdownMenuEntry(
                          value: TaskBreakWindow.long,
                          label: l10n.breakWindowLong,
                        ),
                        DropdownMenuEntry(
                          value: TaskBreakWindow.both,
                          label: l10n.breakWindowBoth,
                        ),
                      ],
                      onSelected: (v) {
                        if (v != null) setState(() => _breakWindow = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(l10n.alwaysShownLabel),
                      value: _alwaysShown,
                      onChanged: (v) => setState(() => _alwaysShown = v),
                    ),
                    // Fixed-height error slot: always present so layout does not jump.
                    const SizedBox(height: 8),
                    _ErrorSlot(message: errorMsg),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      key: const ValueKey('addTaskSubmitButton'),
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.addTaskButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fixed-height error slot (mirrors sign_in_page.dart)
// ---------------------------------------------------------------------------

class _ErrorSlot extends StatelessWidget {
  const _ErrorSlot({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: message != null
          ? Text(
              message!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
    );
  }
}
