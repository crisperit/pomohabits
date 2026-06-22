import 'package:flutter_test/flutter_test.dart';

import 'package:pomohabits/features/focus/timer_config.dart';

void main() {
  group('TimerConfig', () {
    group('defaults', () {
      test('canonical values match Pomodoro spec', () {
        const config = TimerConfig.defaults();
        expect(config.workDuration, const Duration(minutes: 25));
        expect(config.shortBreakDuration, const Duration(minutes: 5));
        expect(config.longBreakDuration, const Duration(minutes: 15));
        expect(config.sessionsUntilLongBreak, 4);
      });
    });

    group('copyWith', () {
      test('returns identical config when no fields supplied', () {
        const original = TimerConfig.defaults();
        final copy = original.copyWith();
        expect(copy, equals(original));
      });

      test('overrides only the supplied fields', () {
        const original = TimerConfig.defaults();
        final copy = original.copyWith(
          workDuration: const Duration(minutes: 30),
          sessionsUntilLongBreak: 6,
        );
        expect(copy.workDuration, const Duration(minutes: 30));
        expect(copy.shortBreakDuration, original.shortBreakDuration);
        expect(copy.longBreakDuration, original.longBreakDuration);
        expect(copy.sessionsUntilLongBreak, 6);
      });
    });

    group('equality', () {
      test('two defaults are equal', () {
        const a = TimerConfig.defaults();
        const b = TimerConfig.defaults();
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('configs differing by one field are not equal', () {
        const a = TimerConfig.defaults();
        final b = a.copyWith(workDuration: const Duration(minutes: 30));
        expect(a, isNot(equals(b)));
      });

      test('identical() shortcut returns true for same instance', () {
        const a = TimerConfig.defaults();
        // ignore: prefer_const_declarations
        final b = a;
        expect(a, equals(b));
      });
    });

    group('toJson / fromJson round-trip', () {
      test('round-trips the default config', () {
        const original = TimerConfig.defaults();
        final json = original.toJson();
        final restored = TimerConfig.fromJson(json);
        expect(restored, equals(original));
      });

      test('round-trips a non-default config', () {
        final original = const TimerConfig.defaults().copyWith(
          workDuration: const Duration(minutes: 50),
          shortBreakDuration: const Duration(minutes: 10),
          longBreakDuration: const Duration(minutes: 30),
          sessionsUntilLongBreak: 6,
        );
        final restored = TimerConfig.fromJson(original.toJson());
        expect(restored, equals(original));
      });

      test('toJson uses whole-minute keys', () {
        const config = TimerConfig.defaults();
        final json = config.toJson();
        expect(json['workMinutes'], 25);
        expect(json['shortBreakMinutes'], 5);
        expect(json['longBreakMinutes'], 15);
        expect(json['sessionsUntilLongBreak'], 4);
      });
    });

    group('fromJson: missing keys fall back to defaults', () {
      const defaults = TimerConfig.defaults();

      test('empty map returns defaults', () {
        final config = TimerConfig.fromJson({});
        expect(config, equals(defaults));
      });

      test('missing workMinutes uses default', () {
        final config = TimerConfig.fromJson({
          'shortBreakMinutes': 5,
          'longBreakMinutes': 15,
          'sessionsUntilLongBreak': 4,
        });
        expect(config.workDuration, defaults.workDuration);
      });

      test('missing sessionsUntilLongBreak uses default', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 25,
          'shortBreakMinutes': 5,
          'longBreakMinutes': 15,
        });
        expect(config.sessionsUntilLongBreak, defaults.sessionsUntilLongBreak);
      });
    });

    group('fromJson: non-int values fall back to defaults', () {
      const defaults = TimerConfig.defaults();

      test('string value for workMinutes uses default', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 'twenty-five',
          'shortBreakMinutes': 5,
          'longBreakMinutes': 15,
          'sessionsUntilLongBreak': 4,
        });
        expect(config.workDuration, defaults.workDuration);
      });

      test('null value for sessionsUntilLongBreak uses default', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 25,
          'shortBreakMinutes': 5,
          'longBreakMinutes': 15,
          'sessionsUntilLongBreak': null,
        });
        expect(config.sessionsUntilLongBreak, defaults.sessionsUntilLongBreak);
      });

      test('double value for longBreakMinutes uses default', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 25,
          'shortBreakMinutes': 5,
          'longBreakMinutes': 15.5,
          'sessionsUntilLongBreak': 4,
        });
        expect(config.longBreakDuration, defaults.longBreakDuration);
      });
    });

    group('fromJson: out-of-range values are clamped', () {
      test('workMinutes = 0 clamps to minWorkMinutes (1)', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 0,
          'shortBreakMinutes': 5,
          'longBreakMinutes': 15,
          'sessionsUntilLongBreak': 4,
        });
        expect(
          config.workDuration,
          const Duration(minutes: TimerConfig.minWorkMinutes),
        );
      });

      test('workMinutes = -10 clamps to minWorkMinutes (1)', () {
        final config = TimerConfig.fromJson({
          'workMinutes': -10,
          'shortBreakMinutes': 5,
          'longBreakMinutes': 15,
          'sessionsUntilLongBreak': 4,
        });
        expect(
          config.workDuration,
          const Duration(minutes: TimerConfig.minWorkMinutes),
        );
      });

      test('workMinutes = 999 clamps to maxWorkMinutes (120)', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 999,
          'shortBreakMinutes': 5,
          'longBreakMinutes': 15,
          'sessionsUntilLongBreak': 4,
        });
        expect(
          config.workDuration,
          const Duration(minutes: TimerConfig.maxWorkMinutes),
        );
      });

      test('shortBreakMinutes = 0 clamps to minShortBreakMinutes (1)', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 25,
          'shortBreakMinutes': 0,
          'longBreakMinutes': 15,
          'sessionsUntilLongBreak': 4,
        });
        expect(
          config.shortBreakDuration,
          const Duration(minutes: TimerConfig.minShortBreakMinutes),
        );
      });

      test('shortBreakMinutes = 200 clamps to maxShortBreakMinutes (60)', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 25,
          'shortBreakMinutes': 200,
          'longBreakMinutes': 15,
          'sessionsUntilLongBreak': 4,
        });
        expect(
          config.shortBreakDuration,
          const Duration(minutes: TimerConfig.maxShortBreakMinutes),
        );
      });

      test('longBreakMinutes = 0 clamps to minLongBreakMinutes (1)', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 25,
          'shortBreakMinutes': 5,
          'longBreakMinutes': 0,
          'sessionsUntilLongBreak': 4,
        });
        expect(
          config.longBreakDuration,
          const Duration(minutes: TimerConfig.minLongBreakMinutes),
        );
      });

      test('longBreakMinutes = 999 clamps to maxLongBreakMinutes (120)', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 25,
          'shortBreakMinutes': 5,
          'longBreakMinutes': 999,
          'sessionsUntilLongBreak': 4,
        });
        expect(
          config.longBreakDuration,
          const Duration(minutes: TimerConfig.maxLongBreakMinutes),
        );
      });

      test('sessionsUntilLongBreak = 0 clamps to minSessionsUntilLongBreak (1)', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 25,
          'shortBreakMinutes': 5,
          'longBreakMinutes': 15,
          'sessionsUntilLongBreak': 0,
        });
        expect(
          config.sessionsUntilLongBreak,
          TimerConfig.minSessionsUntilLongBreak,
        );
      });

      test('sessionsUntilLongBreak = 99 clamps to maxSessionsUntilLongBreak (12)', () {
        final config = TimerConfig.fromJson({
          'workMinutes': 25,
          'shortBreakMinutes': 5,
          'longBreakMinutes': 15,
          'sessionsUntilLongBreak': 99,
        });
        expect(
          config.sessionsUntilLongBreak,
          TimerConfig.maxSessionsUntilLongBreak,
        );
      });

      test('boundary values at min are accepted unchanged', () {
        final config = TimerConfig.fromJson({
          'workMinutes': TimerConfig.minWorkMinutes,
          'shortBreakMinutes': TimerConfig.minShortBreakMinutes,
          'longBreakMinutes': TimerConfig.minLongBreakMinutes,
          'sessionsUntilLongBreak': TimerConfig.minSessionsUntilLongBreak,
        });
        expect(config.workDuration, const Duration(minutes: TimerConfig.minWorkMinutes));
        expect(config.shortBreakDuration, const Duration(minutes: TimerConfig.minShortBreakMinutes));
        expect(config.longBreakDuration, const Duration(minutes: TimerConfig.minLongBreakMinutes));
        expect(config.sessionsUntilLongBreak, TimerConfig.minSessionsUntilLongBreak);
      });

      test('boundary values at max are accepted unchanged', () {
        final config = TimerConfig.fromJson({
          'workMinutes': TimerConfig.maxWorkMinutes,
          'shortBreakMinutes': TimerConfig.maxShortBreakMinutes,
          'longBreakMinutes': TimerConfig.maxLongBreakMinutes,
          'sessionsUntilLongBreak': TimerConfig.maxSessionsUntilLongBreak,
        });
        expect(config.workDuration, const Duration(minutes: TimerConfig.maxWorkMinutes));
        expect(config.shortBreakDuration, const Duration(minutes: TimerConfig.maxShortBreakMinutes));
        expect(config.longBreakDuration, const Duration(minutes: TimerConfig.maxLongBreakMinutes));
        expect(config.sessionsUntilLongBreak, TimerConfig.maxSessionsUntilLongBreak);
      });
    });

    group('toString', () {
      test('includes all field names', () {
        const config = TimerConfig.defaults();
        final s = config.toString();
        expect(s, contains('TimerConfig('));
        expect(s, contains('workDuration'));
        expect(s, contains('shortBreakDuration'));
        expect(s, contains('longBreakDuration'));
        expect(s, contains('sessionsUntilLongBreak'));
      });
    });
  });
}
