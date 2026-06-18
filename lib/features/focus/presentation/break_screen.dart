import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/habit.dart';
import '../../../l10n/app_localizations.dart';
import '../../habits/habits_controller.dart';
import '../break_selection.dart';
import '../builtin_suggestions.dart';
import '../focus_session.dart';
import '../focus_session_controller.dart';

/// Full-screen break presentation shown while a Pomodoro break is active.
///
/// Content (always-shown habits, randomized pick, or built-in suggestion) is
/// computed once when habit data first becomes available and cached for the
/// lifetime of the widget. The break countdown ticks every second and rebuilds
/// this widget; the cached presentation prevents the random pick from
/// reshuffling on each tick.
class BreakScreen extends ConsumerStatefulWidget {
  const BreakScreen({required this.isLongBreak, super.key});

  /// Whether this is a long-break presentation (affects eligibility filtering).
  final bool isLongBreak;

  @override
  ConsumerState<BreakScreen> createState() => _BreakScreenState();
}

class _BreakScreenState extends ConsumerState<BreakScreen> {
  /// Single [Random] instance used for all randomization on this break.
  final Random _random = Random();

  /// Cached result of [selectBreakPresentation], computed once when data lands.
  BreakPresentation? _presentation;

  /// Cached built-in suggestion, computed once alongside [_presentation].
  BuiltInSuggestion? _builtInSuggestion;

  /// Computes and caches [_presentation] and [_builtInSuggestion] from [habits].
  ///
  /// No-op if already cached -- guards against rebuilds triggered by the
  /// countdown ticker.
  void _ensurePresentationCached(List<Habit> habits) {
    if (_presentation != null) return;
    _presentation = selectBreakPresentation(
      habits: habits,
      isLongBreak: widget.isLongBreak,
      random: _random,
    );
    _builtInSuggestion = pickBuiltInSuggestion(_random);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(focusSessionControllerProvider);
    final habitsAsync = ref.watch(habitsListProvider);

    final phaseLabel = widget.isLongBreak
        ? l10n.focusPhaseLongBreak
        : l10n.focusPhaseShortBreak;
    final countdown = formatRemaining(session.remaining);

    return PopScope(
      canPop: false,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            ref.read(focusSessionControllerProvider.notifier).endBreak();
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Phase label + countdown
                    Text(
                      phaseLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      countdown,
                      style: Theme.of(context).textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Content area -- expands to fill remaining space.
                    Expanded(
                      child: habitsAsync.when(
                        data: (habits) {
                          _ensurePresentationCached(habits);
                          final presentation = _presentation!;
                          final suggestion = _builtInSuggestion!;
                          return _buildContent(
                            context,
                            l10n,
                            presentation,
                            suggestion,
                          );
                        },
                        loading: () {
                          // Never-blank guarantee: show a built-in suggestion
                          // while the habits list is still loading.
                          _builtInSuggestion ??= pickBuiltInSuggestion(_random);
                          return _buildSuggestionContent(
                            context,
                            l10n,
                            _builtInSuggestion!,
                          );
                        },
                        error: (e, st) {
                          // Never-blank guarantee: show a built-in suggestion
                          // when loading errored.
                          _builtInSuggestion ??= pickBuiltInSuggestion(_random);
                          return _buildSuggestionContent(
                            context,
                            l10n,
                            _builtInSuggestion!,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Dismiss button
                    ElevatedButton(
                      onPressed: () {
                        ref
                            .read(focusSessionControllerProvider.notifier)
                            .endBreak();
                      },
                      child: Text(l10n.breakEndButton),
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

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    BreakPresentation presentation,
    BuiltInSuggestion suggestion,
  ) {
    // Always-shown habits always render when present. The suggestion replaces
    // only the random slot when the randomized pool is empty (FR-011).
    return ListView(
      children: [
        if (presentation.alwaysShownHabits.isNotEmpty) ...[
          _SectionLabel(label: l10n.breakAlwaysShownLabel),
          ...presentation.alwaysShownHabits.map(
            (habit) => _HabitTile(habit: habit),
          ),
          const SizedBox(height: 16),
        ],
        if (presentation.randomizedHabit != null) ...[
          _SectionLabel(label: l10n.breakRandomLabel),
          _HabitTile(habit: presentation.randomizedHabit!),
        ] else if (presentation.useBuiltInSuggestion) ...[
          _SectionLabel(label: l10n.breakSuggestionLabel),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _suggestionText(l10n, suggestion),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestionContent(
    BuildContext context,
    AppLocalizations l10n,
    BuiltInSuggestion suggestion,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.breakSuggestionLabel,
          style: Theme.of(context).textTheme.titleSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _suggestionText(l10n, suggestion),
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _suggestionText(AppLocalizations l10n, BuiltInSuggestion suggestion) =>
      switch (suggestion) {
        BuiltInSuggestion.stretch => l10n.breakSuggestionStretch,
        BuiltInSuggestion.hydrate => l10n.breakSuggestionHydrate,
        BuiltInSuggestion.lookAway => l10n.breakSuggestionLookAway,
        BuiltInSuggestion.breathe => l10n.breakSuggestionBreathe,
        BuiltInSuggestion.walk => l10n.breakSuggestionWalk,
      };
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: habit.icon != null
          ? Text(habit.icon!, style: const TextStyle(fontSize: 24))
          : habit.alwaysShown
              ? const Icon(Icons.push_pin)
              : const Icon(Icons.task_alt),
      title: Text(habit.name),
    );
  }
}
