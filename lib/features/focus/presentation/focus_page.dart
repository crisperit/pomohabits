import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../focus_session.dart';
import '../focus_session_controller.dart';

class FocusPage extends ConsumerWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(focusSessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.focusTitle),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _phaseLabel(l10n, session.phase),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              _countdownText(session),
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 32),
            _buildControls(context, l10n, ref, session),
          ],
        ),
      ),
    );
  }

  /// Returns the formatted countdown string.
  ///
  /// While idle, shows the upcoming work duration as a preview instead of
  /// `00:00` so the user knows how long the session will be.
  String _countdownText(FocusSessionState session) {
    if (session.phase == FocusPhase.idle) {
      return formatRemaining(focusWorkDuration);
    }
    return formatRemaining(session.remaining);
  }

  String _phaseLabel(AppLocalizations l10n, FocusPhase phase) =>
      switch (phase) {
        FocusPhase.idle => l10n.focusReady,
        FocusPhase.focus => l10n.focusPhaseFocus,
        FocusPhase.shortBreak => l10n.focusPhaseShortBreak,
        FocusPhase.longBreak => l10n.focusPhaseLongBreak,
      };

  Widget _buildControls(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
    FocusSessionState session,
  ) {
    final notifier = ref.read(focusSessionControllerProvider.notifier);

    if (session.phase == FocusPhase.idle) {
      return ElevatedButton(
        onPressed: notifier.start,
        child: Text(l10n.focusStart),
      );
    }

    if (session.isRunning) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: notifier.pause,
            child: Text(l10n.focusPause),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: notifier.stop,
            child: Text(l10n.focusStop),
          ),
        ],
      );
    }

    // Paused: phase != idle && !isRunning
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: notifier.resume,
          child: Text(l10n.focusResume),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: notifier.stop,
          child: Text(l10n.focusStop),
        ),
      ],
    );
  }
}
