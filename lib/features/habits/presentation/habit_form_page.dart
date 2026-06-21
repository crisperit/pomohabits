import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/habit.dart';
import '../../../l10n/app_localizations.dart';
import '../habits_controller.dart';

/// A mode-aware habit form.
///
/// Add mode (default): [habit] is null. Calls [HabitsController.addHabit] on
/// submit and shows [AppLocalizations.addHabitTitle] / [AppLocalizations.addHabitButton].
///
/// Edit mode: [habit] is non-null. Pre-fills every field from [habit], calls
/// [HabitsController.updateHabit] on submit, and shows
/// [AppLocalizations.editHabitTitle] / [AppLocalizations.saveHabitButton].
/// The duplicate-name check skips the habit being edited.
class HabitFormPage extends ConsumerStatefulWidget {
  const HabitFormPage({super.key, this.habit});

  final Habit? habit;

  @override
  ConsumerState<HabitFormPage> createState() => _HabitFormPageState();
}

class _HabitFormPageState extends ConsumerState<HabitFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late HabitCategory _category;
  late HabitBreakWindow _breakWindow;
  late bool _alwaysShown;
  String? _icon;

  bool get _isEditMode => widget.habit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _nameController.text = widget.habit!.name;
      _category = widget.habit!.category;
      _breakWindow = widget.habit!.applicableBreakWindow;
      _alwaysShown = widget.habit!.alwaysShown;
      _icon = widget.habit!.icon;
    } else {
      _category = HabitCategory.daily;
      _breakWindow = HabitBreakWindow.both;
      _alwaysShown = false;
      _icon = null;
    }
  }

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
    return l10n.habitErrorUnexpected;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();

    if (_isEditMode) {
      final updated = await ref
          .read(habitsControllerProvider.notifier)
          .updateHabit(
            id: widget.habit!.id,
            name: name,
            category: _category,
            applicableBreakWindow: _breakWindow,
            alwaysShown: _alwaysShown,
            icon: _icon,
          );
      if (!mounted) return;

      if (updated != null) {
        ref.invalidate(habitsListProvider);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.habitUpdatedSuccess)),
        );
        context.pop();
      }
    } else {
      final created = await ref
          .read(habitsControllerProvider.notifier)
          .addHabit(
            name: name,
            category: _category,
            applicableBreakWindow: _breakWindow,
            alwaysShown: _alwaysShown,
            icon: _icon,
          );
      if (!mounted) return;

      if (created != null) {
        ref.invalidate(habitsListProvider);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.habitAddedSuccess)),
        );
        context.pop();
      }
    }
  }

  void _openEmojiPicker(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          l10n.habitIconLabel,
                          style: Theme.of(builderContext).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        if (_icon != null)
                          TextButton(
                            onPressed: () {
                              setState(() => _icon = null);
                              Navigator.pop(sheetContext);
                            },
                            child: Text(l10n.habitIconRemove),
                          ),
                      ],
                    ),
                  ),
                  EmojiPicker(
                    onEmojiSelected: (Category? category, Emoji emoji) {
                      setState(() => _icon = emoji.emoji);
                      Navigator.pop(sheetContext);
                    },
                    config: Config(
                      height: 300,
                      checkPlatformCompatibility: true,
                      viewOrderConfig: const ViewOrderConfig(
                        top: EmojiPickerItem.searchBar,
                        middle: EmojiPickerItem.emojiView,
                        bottom: EmojiPickerItem.categoryBar,
                      ),
                      emojiViewConfig: EmojiViewConfig(
                        backgroundColor: cs.surface,
                        noRecents: Text(
                          'No recents',
                          style: TextStyle(
                            fontSize: 20,
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      searchViewConfig: SearchViewConfig(
                        backgroundColor: cs.surfaceContainerHighest,
                        buttonIconColor: cs.onSurfaceVariant,
                        inputTextStyle: TextStyle(color: cs.onSurface),
                        hintTextStyle: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        backgroundColor: cs.surface,
                        iconColor: cs.onSurfaceVariant,
                        iconColorSelected: cs.primary,
                        indicatorColor: cs.primary,
                        backspaceColor: cs.primary,
                      ),
                      bottomActionBarConfig: BottomActionBarConfig(
                        backgroundColor: cs.surface,
                        buttonColor: cs.surface,
                        buttonIconColor: cs.onSurfaceVariant,
                      ),
                      skinToneConfig: SkinToneConfig(
                        dialogBackgroundColor: cs.surfaceContainer,
                        indicatorColor: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final habitsState = ref.watch(habitsControllerProvider);
    final isLoading = habitsState.isLoading;
    final errorMsg = _errorMessage(l10n, habitsState);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? l10n.editHabitTitle : l10n.addHabitTitle),
      ),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: l10n.habitIconLabel,
                          child: InkWell(
                            key: const ValueKey('habitIconButton'),
                            onTap: () => _openEmojiPicker(context, l10n),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: _icon != null
                                  ? Text(
                                      _icon!,
                                      style: const TextStyle(fontSize: 24),
                                    )
                                  : Icon(
                                      Icons.emoji_emotions_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey('habitNameField'),
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: l10n.habitNameLabel,
                            ),
                            maxLength: 200,
                            maxLengthEnforcement: MaxLengthEnforcement.none,
                            textInputAction: TextInputAction.done,
                            validator: (v) {
                              final trimmed = v?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return l10n.habitErrorNameRequired;
                              }
                              if (trimmed.length > 200) {
                                return l10n.habitErrorNameTooLong;
                              }
                              final existing = ref.read(habitsListProvider).value;
                              if (existing != null) {
                                final lower = trimmed.toLowerCase();
                                final isDuplicate = existing.any(
                                  (h) =>
                                      h.name.trim().toLowerCase() == lower &&
                                      (_isEditMode
                                          ? h.id != widget.habit!.id
                                          : true),
                                );
                                if (isDuplicate) {
                                  return l10n.habitErrorNameDuplicate;
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownMenu<HabitCategory>(
                      initialSelection: _category,
                      label: Text(l10n.habitCategoryLabel),
                      expandedInsets: EdgeInsets.zero,
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          value: HabitCategory.oneTime,
                          label: l10n.categoryOneTime,
                        ),
                        DropdownMenuEntry(
                          value: HabitCategory.daily,
                          label: l10n.categoryDaily,
                        ),
                        DropdownMenuEntry(
                          value: HabitCategory.unlimited,
                          label: l10n.categoryUnlimited,
                        ),
                      ],
                      onSelected: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownMenu<HabitBreakWindow>(
                      initialSelection: _breakWindow,
                      label: Text(l10n.breakWindowLabel),
                      expandedInsets: EdgeInsets.zero,
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          value: HabitBreakWindow.short,
                          label: l10n.breakWindowShort,
                        ),
                        DropdownMenuEntry(
                          value: HabitBreakWindow.long,
                          label: l10n.breakWindowLong,
                        ),
                        DropdownMenuEntry(
                          value: HabitBreakWindow.both,
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
                      key: ValueKey(
                        _isEditMode
                            ? 'saveHabitSubmitButton'
                            : 'addHabitSubmitButton',
                      ),
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isEditMode
                                  ? l10n.saveHabitButton
                                  : l10n.addHabitButton,
                            ),
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
