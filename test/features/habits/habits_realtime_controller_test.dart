import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pomohabits/core/supabase/auth_providers.dart';
import 'package:pomohabits/core/time/timezone_providers.dart';
import 'package:pomohabits/data/habit.dart';
import 'package:pomohabits/data/habits_repository.dart';
import 'package:pomohabits/features/habits/habits_controller.dart';
import 'package:pomohabits/features/habits/habits_realtime_controller.dart';

void main() {
  group('HabitsRealtimeController', () {
    test('invalidates habitsListProvider on stream event', () async {
      var fetchCount = 0;
      final changeController = StreamController<void>();
      final fake = _FakeHabitsRepository(
        changesStream: changeController.stream,
        onFetch: () {
          fetchCount++;
          return [];
        },
      );

      final container = ProviderContainer(
        overrides: [
          habitsRepositoryProvider.overrideWithValue(fake),
          currentUserIdProvider.overrideWith((_) => 'user-123'),
          localTimezoneProvider.overrideWith(
            (_) => Future.value('UTC'),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Trigger habitsListProvider to load (fetchCount becomes 1).
      await container.read(habitsListProvider.future);
      expect(fetchCount, 1);

      // Instantiate the realtime controller so it subscribes.
      container.read(habitsRealtimeControllerProvider);

      // Emit a change event from the fake stream.
      changeController.add(null);

      // Poll a bounded number of microtasks until the invalidation-driven
      // re-fetch lands, to avoid depending on a single microtask cycle.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
        await container.read(habitsListProvider.future);
        if (fetchCount >= 2) break;
      }
      expect(fetchCount, 2,
          reason: 'habitsListProvider should re-fetch after stream event');

      await changeController.close();
    });

    test('does not subscribe when unauthenticated', () async {
      var habitChangesCalled = false;
      final fake = _FakeHabitsRepository(
        changesStream: const Stream<void>.empty(),
        onFetch: () => [],
        onHabitChangesCalled: () => habitChangesCalled = true,
      );

      final container = ProviderContainer(
        overrides: [
          habitsRepositoryProvider.overrideWithValue(fake),
          currentUserIdProvider.overrideWith((_) => null),
          localTimezoneProvider.overrideWith(
            (_) => Future.value('UTC'),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(habitsRealtimeControllerProvider);

      // Allow any async work to settle.
      await Future<void>.delayed(Duration.zero);

      expect(habitChangesCalled, isFalse,
          reason: 'habitChanges must not be called when user id is null');
    });

    test('cancels subscription when container is disposed', () async {
      var cancelFired = false;
      final changeController = StreamController<void>(
        onCancel: () => cancelFired = true,
      );
      final fake = _FakeHabitsRepository(
        changesStream: changeController.stream,
        onFetch: () => [],
      );

      final container = ProviderContainer(
        overrides: [
          habitsRepositoryProvider.overrideWithValue(fake),
          currentUserIdProvider.overrideWith((_) => 'user-123'),
          localTimezoneProvider.overrideWith(
            (_) => Future.value('UTC'),
          ),
        ],
      );

      // Start the subscription.
      container.read(habitsRealtimeControllerProvider);
      await Future<void>.delayed(Duration.zero);

      // Disposing the container triggers ref.onDispose, which cancels _sub.
      container.dispose();

      // Allow async teardown to settle.
      await Future<void>.delayed(Duration.zero);

      expect(cancelFired, isTrue,
          reason: 'stream onCancel must fire when container is disposed');

      await changeController.close();
    });
  });
}

// ---------------------------------------------------------------------------
// Hand-rolled fake -- no mocking library, mirrors habits_controller_test.dart
// ---------------------------------------------------------------------------

class _FakeHabitsRepository implements HabitsRepository {
  _FakeHabitsRepository({
    required this.changesStream,
    required this.onFetch,
    this.onHabitChangesCalled,
  });

  final Stream<void> changesStream;
  final List<Habit> Function() onFetch;
  final void Function()? onHabitChangesCalled;

  @override
  Stream<void> habitChanges({required String userId}) {
    onHabitChangesCalled?.call();
    return changesStream;
  }

  @override
  Future<List<Habit>> fetchHabits({String timezone = 'UTC'}) async {
    return onFetch();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
