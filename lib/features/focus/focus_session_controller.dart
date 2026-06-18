import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'focus_session.dart';

// ---------------------------------------------------------------------------
// Ticker seam -- injectable so unit tests drive transitions synchronously.
// ---------------------------------------------------------------------------

/// A handle returned by [TickerFactory] that allows the holder to cancel the
/// periodic tick subscription.
abstract class TickerHandle {
  void cancel();
}

/// Creates a periodic ticker that fires [onTick] once per second (or on the
/// test-controlled schedule) and returns a [TickerHandle] to cancel it.
typedef TickerFactory = TickerHandle Function(void Function() onTick);

/// Real production ticker: wraps [Timer.periodic] with a 1-second interval.
TickerHandle _realTicker(void Function() onTick) {
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => onTick());
  return _TimerHandle(timer);
}

class _TimerHandle implements TickerHandle {
  _TimerHandle(this._timer);
  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

/// Riverpod provider for the ticker factory. Override in tests with a
/// [FakeTickerFactory] to drive transitions without wall-clock delays.
final tickerFactoryProvider = Provider<TickerFactory>(
  (ref) => _realTicker,
);

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class FocusSessionController extends Notifier<FocusSessionState> {
  TickerHandle? _ticker;

  @override
  FocusSessionState build() {
    ref.onDispose(_cancelTicker);
    return const FocusSessionState.initial();
  }

  /// Starts a new focus session from idle (or restarts from any phase).
  void start() {
    _cancelTicker();
    state = FocusSessionState(
      phase: FocusPhase.focus,
      remaining: focusWorkDuration,
      isRunning: true,
      completedFocusSessions: state.completedFocusSessions,
    );
    _startTicker();
  }

  /// Pauses the running countdown without resetting remaining time.
  void pause() {
    if (!state.isRunning) return;
    _cancelTicker();
    state = state.copyWith(isRunning: false);
  }

  /// Resumes a paused countdown.
  void resume() {
    if (state.isRunning || state.phase == FocusPhase.idle) return;
    state = state.copyWith(isRunning: true);
    _startTicker();
  }

  /// Resets to idle and cancels any active timer.
  void reset() {
    _cancelTicker();
    state = const FocusSessionState.initial();
  }

  /// Alias for [reset] -- matches the plan's stop() name.
  void stop() => reset();

  /// Immediately ends the current break and advances to the next focus session.
  ///
  /// This is the dismiss hatch that satisfies the "never trap the user behind
  /// an unkillable full-screen surface" guardrail (FR-007). If the session is
  /// not currently in a break phase, this is a no-op.
  void endBreak() {
    if (!state.phase.isBreak) return;
    _cancelTicker();
    _advancePhase();
    if (state.phase != FocusPhase.idle) _startTicker();
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  void _startTicker() {
    final factory = ref.read(tickerFactoryProvider);
    _ticker = factory(_onTick);
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTick() {
    if (!state.isRunning) return;

    final newRemaining = state.remaining - const Duration(seconds: 1);

    if (newRemaining > Duration.zero) {
      state = state.copyWith(remaining: newRemaining);
      return;
    }

    // Remaining hit zero -- advance the phase.
    _cancelTicker();
    _advancePhase();
    if (state.phase != FocusPhase.idle) _startTicker();
  }

  void _advancePhase() {
    switch (state.phase) {
      case FocusPhase.focus:
        final completed = state.completedFocusSessions + 1;
        final nextPhase = completed % sessionsUntilLongBreak == 0
            ? FocusPhase.longBreak
            : FocusPhase.shortBreak;
        final breakDuration = nextPhase == FocusPhase.longBreak
            ? focusLongBreakDuration
            : focusShortBreakDuration;
        state = FocusSessionState(
          phase: nextPhase,
          remaining: breakDuration,
          isRunning: true,
          completedFocusSessions: completed,
        );

      case FocusPhase.shortBreak:
      case FocusPhase.longBreak:
        state = FocusSessionState(
          phase: FocusPhase.focus,
          remaining: focusWorkDuration,
          isRunning: true,
          completedFocusSessions: state.completedFocusSessions,
        );

      case FocusPhase.idle:
        // Should not happen; do nothing.
        break;
    }
  }
}

final focusSessionControllerProvider =
    NotifierProvider<FocusSessionController, FocusSessionState>(
  FocusSessionController.new,
);
