import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/features/focus/timer_config.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [ProviderContainer] with [SharedPreferences] pre-seeded with
/// [initialValues] and overrides [sharedPreferencesProvider] accordingly.
Future<ProviderContainer> makeContainer({
  Map<String, Object> initialValues = const {},
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  return container;
}

/// A minimal [SharedPreferences] stub whose [setString] always throws.
/// [getString] returns null so [TimerConfigNotifier.build] yields defaults.
/// All other methods are routed to [noSuchMethod] which throws by default;
/// those paths are never reached by the test.
class _ThrowingPrefs implements SharedPreferences {
  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) async =>
      throw Exception('write failed');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TimerConfigNotifier', () {
    test('returns defaults when timer_config key is absent', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final config = container.read(timerConfigProvider);
      expect(config, equals(const TimerConfig.defaults()));
    });

    test('loads a previously stored valid config', () async {
      const stored = TimerConfig(
        workDuration: Duration(minutes: 30),
        shortBreakDuration: Duration(minutes: 8),
        longBreakDuration: Duration(minutes: 20),
        sessionsUntilLongBreak: 6,
      );
      final container = await makeContainer(
        initialValues: {
          'timer_config': jsonEncode(stored.toJson()),
        },
      );
      addTearDown(container.dispose);

      final config = container.read(timerConfigProvider);
      expect(config, equals(stored));
    });

    test('returns defaults when stored value is malformed JSON', () async {
      final container = await makeContainer(
        initialValues: {'timer_config': 'not-valid-json{{{'},
      );
      addTearDown(container.dispose);

      final config = container.read(timerConfigProvider);
      expect(config, equals(const TimerConfig.defaults()));
    });

    test('returns defaults when stored JSON is not a map', () async {
      final container = await makeContainer(
        initialValues: {'timer_config': jsonEncode([1, 2, 3])},
      );
      addTearDown(container.dispose);

      final config = container.read(timerConfigProvider);
      expect(config, equals(const TimerConfig.defaults()));
    });

    test('returns defaults when stored value is an empty string', () async {
      final container = await makeContainer(
        initialValues: {'timer_config': ''},
      );
      addTearDown(container.dispose);

      final config = container.read(timerConfigProvider);
      expect(config, equals(const TimerConfig.defaults()));
    });

    test('set() updates state immediately (optimistic)', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      const newConfig = TimerConfig(
        workDuration: Duration(minutes: 45),
        shortBreakDuration: Duration(minutes: 10),
        longBreakDuration: Duration(minutes: 25),
        sessionsUntilLongBreak: 3,
      );

      await container.read(timerConfigProvider.notifier).set(newConfig);

      expect(container.read(timerConfigProvider), equals(newConfig));
    });

    test('set() persists the config so a new container reads it back', () async {
      // First container: write a new config.
      final container1 = await makeContainer();
      addTearDown(container1.dispose);

      const newConfig = TimerConfig(
        workDuration: Duration(minutes: 50),
        shortBreakDuration: Duration(minutes: 10),
        longBreakDuration: Duration(minutes: 30),
        sessionsUntilLongBreak: 2,
      );
      await container1.read(timerConfigProvider.notifier).set(newConfig);

      // Read raw prefs to verify the key was written.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('timer_config');
      expect(raw, isNotNull);

      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      final restored = TimerConfig.fromJson(decoded);
      expect(restored, equals(newConfig));
    });

    test('set() reverts state and rethrows when setString throws', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(_ThrowingPrefs()),
        ],
      );
      addTearDown(container.dispose);

      // build() calls getString which returns null, so state is defaults.
      final previous = container.read(timerConfigProvider);
      expect(previous, equals(const TimerConfig.defaults()));

      const newConfig = TimerConfig(
        workDuration: Duration(minutes: 45),
        shortBreakDuration: Duration(minutes: 10),
        longBreakDuration: Duration(minutes: 25),
        sessionsUntilLongBreak: 3,
      );

      // set() must rethrow the write failure.
      await expectLater(
        container.read(timerConfigProvider.notifier).set(newConfig),
        throwsA(isA<Exception>()),
      );

      // State must have rolled back to the previous value.
      expect(container.read(timerConfigProvider), equals(previous));
    });

    test('set() with clamped values stores valid JSON that round-trips', () async {
      final container = await makeContainer(
        initialValues: {
          'timer_config': jsonEncode({
            'workMinutes': 25,
            'shortBreakMinutes': 5,
            'longBreakMinutes': 15,
            'sessionsUntilLongBreak': 4,
          }),
        },
      );
      addTearDown(container.dispose);

      // Overwrite with new valid config.
      const updated = TimerConfig(
        workDuration: Duration(minutes: 20),
        shortBreakDuration: Duration(minutes: 5),
        longBreakDuration: Duration(minutes: 15),
        sessionsUntilLongBreak: 4,
      );
      await container.read(timerConfigProvider.notifier).set(updated);

      expect(container.read(timerConfigProvider), equals(updated));
    });
  });
}
