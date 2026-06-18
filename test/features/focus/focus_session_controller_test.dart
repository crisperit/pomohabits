import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pomohabits/features/focus/focus_session.dart';
import 'package:pomohabits/features/focus/focus_session_controller.dart';

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

ProviderContainer makeContainer(FakeTickerFactory fake) {
  final container = ProviderContainer(
    overrides: [
      tickerFactoryProvider.overrideWithValue(fake.call),
    ],
  );
  return container;
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
      expect(s.remaining, focusWorkDuration);
      expect(s.completedFocusSessions, 0);
    });

    test('ticks decrement remaining by 1 second each', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      fake.tickN(3);

      final s = container.read(focusSessionControllerProvider);
      expect(s.remaining, focusWorkDuration - const Duration(seconds: 3));
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
          focusWorkDuration - const Duration(seconds: 5));

      // Ticking after pause should have no effect (ticker was cancelled).
      fake.tickN(10);
      final afterExtraTicks = container.read(focusSessionControllerProvider);
      expect(afterExtraTicks.remaining,
          focusWorkDuration - const Duration(seconds: 5));
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
          focusWorkDuration - const Duration(seconds: 8));
    });

    test('focus phase reaching zero transitions to shortBreak, '
        'completedFocusSessions == 1', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      // Tick until the last second of focus.
      final focusTicks = focusWorkDuration.inSeconds;
      fake.tickN(focusTicks);

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.shortBreak);
      expect(s.isRunning, isTrue);
      expect(s.remaining, focusShortBreakDuration);
      expect(s.completedFocusSessions, 1);
    });

    test('4th focus completion transitions to longBreak', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();

      // Complete 3 focus+short-break cycles, then 1 more focus.
      for (var cycle = 0; cycle < 3; cycle++) {
        fake.tickN(focusWorkDuration.inSeconds); // focus -> shortBreak
        fake.tickN(focusShortBreakDuration.inSeconds); // shortBreak -> focus
      }
      // 4th focus phase completes.
      fake.tickN(focusWorkDuration.inSeconds);

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.longBreak);
      expect(s.isRunning, isTrue);
      expect(s.remaining, focusLongBreakDuration);
      expect(s.completedFocusSessions, 4);
    });

    test('short break reaching zero transitions back to focus', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      fake.tickN(focusWorkDuration.inSeconds); // -> shortBreak
      fake.tickN(focusShortBreakDuration.inSeconds); // -> focus

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.focus);
      expect(s.isRunning, isTrue);
      expect(s.remaining, focusWorkDuration);
    });

    test('long break reaching zero transitions back to focus', () {
      final fake = FakeTickerFactory();
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      container.read(focusSessionControllerProvider.notifier).start();
      for (var cycle = 0; cycle < 3; cycle++) {
        fake.tickN(focusWorkDuration.inSeconds);
        fake.tickN(focusShortBreakDuration.inSeconds);
      }
      fake.tickN(focusWorkDuration.inSeconds); // -> longBreak
      fake.tickN(focusLongBreakDuration.inSeconds); // -> focus

      final s = container.read(focusSessionControllerProvider);
      expect(s.phase, FocusPhase.focus);
      expect(s.isRunning, isTrue);
      expect(s.remaining, focusWorkDuration);
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

      fake.tickN(focusWorkDuration.inSeconds); // -> shortBreak
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
        fake.tickN(focusWorkDuration.inSeconds);
        fake.tickN(focusShortBreakDuration.inSeconds);
      }
      fake.tickN(focusWorkDuration.inSeconds); // -> longBreak

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
        fake.tickN(focusWorkDuration.inSeconds); // -> shortBreak

        expect(
          container.read(focusSessionControllerProvider).phase,
          FocusPhase.shortBreak,
        );

        container.read(focusSessionControllerProvider.notifier).endBreak();

        final s = container.read(focusSessionControllerProvider);
        expect(s.phase, FocusPhase.focus);
        expect(s.isRunning, isTrue);
        expect(s.remaining, focusWorkDuration);
      });

      test('in longBreak -> advances to focus, running', () {
        final fake = FakeTickerFactory();
        final container = makeContainer(fake);
        addTearDown(container.dispose);

        container.read(focusSessionControllerProvider.notifier).start();
        for (var cycle = 0; cycle < 3; cycle++) {
          fake.tickN(focusWorkDuration.inSeconds);
          fake.tickN(focusShortBreakDuration.inSeconds);
        }
        fake.tickN(focusWorkDuration.inSeconds); // -> longBreak

        expect(
          container.read(focusSessionControllerProvider).phase,
          FocusPhase.longBreak,
        );

        container.read(focusSessionControllerProvider.notifier).endBreak();

        final s = container.read(focusSessionControllerProvider);
        expect(s.phase, FocusPhase.focus);
        expect(s.isRunning, isTrue);
        expect(s.remaining, focusWorkDuration);
      });

      test('paused break -> endBreak() transitions to running focus', () {
        final fake = FakeTickerFactory();
        final container = makeContainer(fake);
        addTearDown(container.dispose);

        container.read(focusSessionControllerProvider.notifier).start();
        fake.tickN(focusWorkDuration.inSeconds); // -> shortBreak, running

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
        expect(s.remaining, focusWorkDuration);
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
          focusWorkDuration - const Duration(seconds: 10),
        );
      });
    });
  });
}
