/// Canonical Pomodoro configuration constants.
///
/// All durations live here so S-07 can later make them user-configurable
/// by replacing these consts with a provider-driven source.
const Duration focusWorkDuration = Duration(minutes: 25);
const Duration focusShortBreakDuration = Duration(minutes: 5);
const Duration focusLongBreakDuration = Duration(minutes: 15);
const int sessionsUntilLongBreak = 4;

/// The phase the Pomodoro state machine is currently in.
enum FocusPhase {
  idle,
  focus,
  shortBreak,
  longBreak;

  /// Whether this phase is any kind of break.
  bool get isBreak => this == shortBreak || this == longBreak;
}

/// Immutable snapshot of focus-session state consumed by the UI and controller.
class FocusSessionState {
  const FocusSessionState({
    required this.phase,
    required this.remaining,
    required this.isRunning,
    required this.completedFocusSessions,
  });

  /// Returns the idle / not-started initial state.
  const FocusSessionState.initial()
      : phase = FocusPhase.idle,
        remaining = Duration.zero,
        isRunning = false,
        completedFocusSessions = 0;

  final FocusPhase phase;

  /// Time left in the current phase.
  final Duration remaining;

  /// `true` while the countdown is actively decrementing; `false` when paused.
  final bool isRunning;

  /// Number of focus phases that have completed (incremented when a focus phase
  /// reaches zero, before transitioning to the break phase).
  final int completedFocusSessions;

  /// Whether the current phase is any kind of break.
  bool get isBreak => phase.isBreak;

  /// Whether the current phase is specifically a long break.
  bool get isLongBreak => phase == FocusPhase.longBreak;

  FocusSessionState copyWith({
    FocusPhase? phase,
    Duration? remaining,
    bool? isRunning,
    int? completedFocusSessions,
  }) {
    return FocusSessionState(
      phase: phase ?? this.phase,
      remaining: remaining ?? this.remaining,
      isRunning: isRunning ?? this.isRunning,
      completedFocusSessions:
          completedFocusSessions ?? this.completedFocusSessions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusSessionState &&
        other.phase == phase &&
        other.remaining == remaining &&
        other.isRunning == isRunning &&
        other.completedFocusSessions == completedFocusSessions;
  }

  @override
  int get hashCode => Object.hash(
        phase,
        remaining,
        isRunning,
        completedFocusSessions,
      );

  @override
  String toString() =>
      'FocusSessionState(phase: $phase, remaining: $remaining, '
      'isRunning: $isRunning, completedFocusSessions: $completedFocusSessions)';
}
