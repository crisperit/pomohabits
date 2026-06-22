import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/features/focus/focus_session.dart';
import 'package:pomohabits/features/focus/focus_session_controller.dart';
import 'package:pomohabits/features/focus/timer_config.dart';

// ---------------------------------------------------------------------------
// Fake ticker -- fires ticks on demand, no wall-clock waits.
// ---------------------------------------------------------------------------

class FakeTickerHandle implements TickerHandle {
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

class FakeTickerFactory {
  /// All active (non-cancelled) handles, in creation order.
  final List<FakeTickerHandle> handles = [];

  /// The last registered callback.
  void Function()? _onTick;

  /// Returns [this] as the [TickerFactory] typedef for use in overrides.
  TickerHandle call(void Function() onTick) {
    _onTick = onTick;
    final handle = FakeTickerHandle();
    handles.add(handle);
    return handle;
  }

  /// Fires a single tick on the current callback.
  void tick() {
    _onTick?.call();
  }

  /// Fires [n] ticks.
  void tickN(int n) {
    for (var i = 0; i < n; i++) {
      tick();
    }
  }
}

// ---------------------------------------------------------------------------
// Helper to build a container wired to the fake ticker.
// ---------------------------------------------------------------------------

/// Builds a [ProviderContainer] with the fake ticker and an optional
/// [TimerConfig] override (defaults to [TimerConfig.defaults()]).
ProviderContainer makeContainer(
  FakeTickerFactory fake, {
  TimerConfig config = const TimerConfig.defaults(),
}) {
  return ProviderContainer(
    overrides: [
      tickerFactoryProvider.overrideWithValue(fake.call),
      timerConfigProvider.overrideWith(() => _FixedTimerConfigNotifier(config)),
    ],
  );
}

/// A [TimerConfigNotifier] subclass that always returns a fixed [TimerConfig]
/// without touching SharedPreferences. Used by tests that need a specific config.
class _FixedTimerConfigNotifier extends TimerConfigNotifier {
  _FixedTimerConfigNotifier(this._config);
  final TimerConfig _config;

  @override
  TimerConfig build() => _config;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FocusSessionController', () {
    test('initial state is idle, not running, zero remaining', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.idle);
      expect(s.isRunning, isFalse);
      expect(s.remaining, Duration.zero);
      expect(s.completedFocusSessions, 0);
    });

    test('start() transitions to focus phase, running, work duration', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.focus);
      expect(s.isRunning, isTrue);
      expect(s.remaining, const TimerConfig.defaults().workDuration);
      expect(s.completedFocusSessions, 0);
    });

    test('ticks decrement remaining by 1 second each', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      fake.tickN(3);

      final s = container.read(focusSessionControllerProvider);
      expect(s.remaining, const TimerConfig.defaults().workDuration - const Duration(seconds: 3));
    });

    test('pause() stops decrementing and sets isRunning false', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      fake.tickN(5);
      container.read(focusSessionControllerProvider.notifier).pause();

      expect(
        fake.handles.last.cancelled,
        isTrue,
        reason: 'pause must cancel the ticker handle',
      );
      final afterPause = container.read(focusSessionControllerProvider);
      expect(afterPause.isRunning, isFalse);
      expect(afterPause.remaining,
          const TimerConfig.defaults().workDuration - const Duration(seconds: 5));

      // Ticking after pause should have no effect (ticker was cancelled).
      fake.tickN(10);
      final afterExtraTicks = container.read(focusSessionControllerProvider);
      expect(afterExtraTicks.remaining,
          const TimerConfig.defaults().workDuration - const Duration(seconds: 5));
    });

    test('resume() continues from paused remaining', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      fake.tickN(5);
      container.read(focusSessionControllerProvider.notifier).pause();
      container.read(focusSessionControllerProvider.notifier).resume();

      final s = container.read(focusSessionControllerProvider);
      expect(s.isRunning, isTrue);

      fake.tickN(3);
      final after = container.read(focusSessionControllerProvider);
      expect(after.remaining,
          const TimerConfig.defaults().workDuration - const Duration(seconds: 8));
    });

    test('focus phase reaching zero transitions to shortBreak, '
        'completedFocusSessions == 1', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      // Tick until the last second of focus.
      final focusTicks = const TimerConfig.defaults().workDuration.inSeconds;
      fake.tickN(focusTicks);

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.shortBreak);
      expect(s.isRunning, isTrue);
      expect(s.remaining, const TimerConfig.defaults().shortBreakDuration);
      expect(s.completedFocusSessions, 1);
    });

    test('4th focus completion transitions to longBreak', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();

      // Complete 3 focus+short-break cycles, then 1 more focus.
      for (var cycle = 0; cycle < 3; cycle++) {
        fake.tickN(const TimerConfig.defaults().workDuration.inSeconds); // focus -> shortBreak
        fake.tickN(const TimerConfig.defaults().shortBreakDuration.inSeconds); // shortBreak -> focus
      }
      // 4th focus phase completes.
      fake.tickN(const TimerConfig.defaults().workDuration.inSeconds);

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.longBreak);
      expect(s.isRunning, isTrue);
      expect(s.remaining, const TimerConfig.defaults().longBreakDuration);
      expect(s.completedFocusSessions, 4);
    });

    test('short break reaching zero transitions back to focus', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      fake.tickN(const TimerConfig.defaults().workDuration.inSeconds); // -> shortBreak
      fake.tickN(const TimerConfig.defaults().shortBreakDuration.inSeconds); // -> focus

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.focus);
      expect(s.isRunning, isTrue);
      expect(s.remaining, const TimerConfig.defaults().workDuration);
    });

    test('long break reaching zero transitions back to focus', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      for (var cycle = 0; cycle < 3; cycle++) {
        fake.tickN(const TimerConfig.defaults().workDuration.inSeconds);
        fake.tickN(const TimerConfig.defaults().shortBreakDuration.inSeconds);
      }
      fake.tickN(const TimerConfig.defaults().workDuration.inSeconds); // -> longBreak
      fake.tickN(const TimerConfig.defaults().longBreakDuration.inSeconds); // -> focus

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.focus);
      expect(s.isRunning, isTrue);
      expect(s.remaining, const TimerConfig.defaults().workDuration);
    });

    test('reset() returns to idle regardless of phase', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      fake.tickN(10);
      container.read(focusSessionControllerProvider.notifier).reset();

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.idle);
      expect(s.isRunning, isFalse);
      expect(s.remaining, Duration.zero);
      expect(s.completedFocusSessions, 0);

      // Ticking after reset has no effect.
      fake.tickN(5);
      expect(container.read(focusSessionControllerProvider).phase,
          FocusPhase.idle);
    });

    test('stop() is an alias for reset()', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      container.read(focusSessionControllerProvider.notifier).stop();

      expect(
        container.read(focusSessionControllerProvider).phase,
        FocusPhase.idle,
      );
    });

    test('isBreak getter is true during shortBreak and longBreak', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      expect(container.read(focusSessionControllerProvider).isBreak, isFalse);

      fake.tickN(const TimerConfig.defaults().workDuration.inSeconds); // -> shortBreak
      expect(container.read(focusSessionControllerProvider).isBreak, isTrue);
      expect(container.read(focusSessionControllerProvider).isLongBreak,
          isFalse);
    });

    test('isLongBreak getter is true only during longBreak', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      for (var cycle = 0; cycle < 3; cycle++) {
        fake.tickN(const TimerConfig.defaults().workDuration.inSeconds);
        fake.tickN(const TimerConfig.defaults().shortBreakDuration.inSeconds);
      }
      fake.tickN(const TimerConfig.defaults().workDuration.inSeconds); // -> longBreak

      expect(container.read(focusSessionControllerProvider).isLongBreak,
          isTrue);
    });

    test('FocusSessionState equality holds for identical values', () {
      const a = FocusSessionState(
        phase: FocusPhase.focus,
        remaining: Duration(minutes: 20),
        isRunning: true,
        completedFocusSessions: 1,
      );
      const b = FocusSessionState(
        phase: FocusPhase.focus,
        remaining: Duration(minutes: 20),
        isRunning: true,
        completedFocusSessions: 1,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    group('endBreak()', () {
      test('in shortBreak -> advances to focus, running', () {
        final fake = FakeTickerFactory();
        final container = makeContainer(fake);
        addTearDown(container.dispose);

        container.read(focusSessionControllerProvider.notifier).start();
        fake.tickN(const TimerConfig.defaults().workDuration.inSeconds); // -> shortBreak

        expect(
          container.read(focusSessionControllerProvider).phase,
          FocusPhase.shortBreak,
        );

        container.read(focusSessionControllerProvider.notifier).endBreak();

        final s = container.read(focusSessionControllerProvider);
        expect(s.phase, FocusPhase.focus);
        expect(s.isRunning, isTrue);
        expect(s.remaining, const TimerConfig.defaults().workDuration);
      });

      test('in longBreak -> advances to focus, running', () {
        final fake = FakeTickerFactory();
        final container = makeContainer(fake);
        addTearDown(container.dispose);

        container.read(focusSessionControllerProvider.notifier).start();
        for (var cycle = 0; cycle < 3; cycle++) {
          fake.tickN(const TimerConfig.defaults().workDuration.inSeconds);
          fake.tickN(const TimerConfig.defaults().shortBreakDuration.inSeconds);
        }
        fake.tickN(const TimerConfig.defaults().workDuration.inSeconds); // -> longBreak

        expect(
          container.read(focusSessionControllerProvider).phase,
          FocusPhase.longBreak,
        );

        container.read(focusSessionControllerProvider.notifier).endBreak();

        final s = container.read(focusSessionControllerProvider);
        expect(s.phase, FocusPhase.focus);
        expect(s.isRunning, isTrue);
        expect(s.remaining, const TimerConfig.defaults().workDuration);
      });

      test('paused break -> endBreak() transitions to running focus', () {
        final fake = FakeTickerFactory();
        final container = makeContainer(fake);
        addTearDown(container.dispose);

        container.read(focusSessionControllerProvider.notifier).start();
        fake.tickN(const TimerConfig.defaults().workDuration.inSeconds); // -> shortBreak, running

        expect(
          container.read(focusSessionControllerProvider).phase,
          FocusPhase.shortBreak,
        );

        container.read(focusSessionControllerProvider.notifier).pause();
        expect(
          container.read(focusSessionControllerProvider).isRunning,
          isFalse,
        );

        container.read(focusSessionControllerProvider.notifier).endBreak();

        final s = container.read(focusSessionControllerProvider);
        expect(s.phase, FocusPhase.focus);
        expect(s.isRunning, isTrue);
        expect(s.remaining, const TimerConfig.defaults().workDuration);
      });

      test('no-op when idle', () {
        final fake = FakeTickerFactory();
        final container = makeContainer(fake);
        addTearDown(container.dispose);

        container.read(focusSessionControllerProvider.notifier).endBreak();

        final s = container.read(focusSessionControllerProvider);
        expect(s.phase, FocusPhase.idle);
      });

      test('no-op when in focus phase', () {
        final fake = FakeTickerFactory();
        final container = makeContainer(fake);
        addTearDown(container.dispose);

        container.read(focusSessionControllerProvider.notifier).start();
        fake.tickN(10);

        container.read(focusSessionControllerProvider.notifier).endBreak();

        final s = container.read(focusSessionControllerProvider);
        expect(s.phase, FocusPhase.focus);
        // remaining should still be decremented by 10 ticks, not reset
        expect(
          s.remaining,
          const TimerConfig.defaults().workDuration - const Duration(seconds: 10),
        );
      });
    });

    group('non-default TimerConfig', () {
      // work 10 min, short break 2 min, long break 20 min, sessions 2
      const customConfig = TimerConfig(
        workDuration: Duration(minutes: 10),
        shortBreakDuration: Duration(minutes: 2),
        longBreakDuration: Duration(minutes: 20),
        sessionsUntilLongBreak: 2,
      );

      test('start() uses configured work duration', () {
        final fake = FakeTickerFactory();
        final container = makeContainer(fake, config: customConfig);
        addTearDown(container.dispose);

        container.read(focusSessionControllerProvider.notifier).start();

        final s = container.read(focusSessionControllerProvider);
        expect(s.phase, FocusPhase.focus);
        expect(s.isRunning, isTrue);
        expect(s.remaining, const Duration(minutes: 10));
      });

      test('focus phase reaching zero transitions to shortBreak with '
          'configured short break duration', () {
        final fake = FakeTickerFactory();
        final container = makeContainer(fake, config: customConfig);
        addTearDown(container.dispose);

        container.read(focusSessionControllerProvider.notifier).start();
        // Drive the 10-min focus phase to zero.
        fake.tickN(const Duration(minutes: 10).inSeconds);

        final s = container.read(focusSessionControllerProvider);
        expect(s.phase, FocusPhase.shortBreak);
        expect(s.isRunning, isTrue);
        expect(s.remaining, const Duration(minutes: 2));
        expect(s.completedFocusSessions, 1);
      });

      test('2nd completed focus session goes to longBreak with configured '
          'long break duration (sessionsUntilLongBreak == 2)', () {
        final fake = FakeTickerFactory();
        final container = makeContainer(fake, config: customConfig);
        addTearDown(container.dispose);

        container.read(focusSessionControllerProvider.notifier).start();

        // Complete 1st focus+short-break cycle.
        fake.tickN(const Duration(minutes: 10).inSeconds); // focus -> shortBreak
        fake.tickN(const Duration(minutes: 2).inSeconds); // shortBreak -> focus

        // Complete 2nd focus phase -- should go to longBreak.
        fake.tickN(const Duration(minutes: 10).inSeconds);

        final s = container.read(focusSessionControllerProvider);
        expect(s.phase, FocusPhase.longBreak);
        expect(s.isRunning, isTrue);
        expect(s.remaining, const Duration(minutes: 20));
        expect(s.completedFocusSessions, 2);
      });
    });
  });
}
