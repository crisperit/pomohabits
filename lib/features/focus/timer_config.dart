/// Immutable Pomodoro timer configuration.
///
/// Holds the four user-configurable values that drive the focus session state
/// machine. Canonical defaults match the consts they will replace in S-07
/// Phase 2.
class TimerConfig {
  const TimerConfig({
    required this.workDuration,
    required this.shortBreakDuration,
    required this.longBreakDuration,
    required this.sessionsUntilLongBreak,
  });

  /// Canonical defaults: 25 min work, 5 min short break, 15 min long break,
  /// 4 sessions until long break. Matches the consts they replace in S-07
  /// Phase 2.
  const TimerConfig.defaults()
      : workDuration = const Duration(minutes: 25),
        shortBreakDuration = const Duration(minutes: 5),
        longBreakDuration = const Duration(minutes: 15),
        sessionsUntilLongBreak = 4;

  final Duration workDuration;
  final Duration shortBreakDuration;
  final Duration longBreakDuration;
  final int sessionsUntilLongBreak;

  // ---------------------------------------------------------------------------
  // Validation bounds (inclusive). Exposed for the Phase 3 UI.
  // ---------------------------------------------------------------------------

  static const int minWorkMinutes = 1;
  static const int maxWorkMinutes = 120;

  static const int minShortBreakMinutes = 1;
  static const int maxShortBreakMinutes = 60;

  static const int minLongBreakMinutes = 1;
  static const int maxLongBreakMinutes = 120;

  static const int minSessionsUntilLongBreak = 1;
  static const int maxSessionsUntilLongBreak = 12;

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Encodes to whole minutes + session count.
  Map<String, int> toJson() => {
        'workMinutes': workDuration.inMinutes,
        'shortBreakMinutes': shortBreakDuration.inMinutes,
        'longBreakMinutes': longBreakDuration.inMinutes,
        'sessionsUntilLongBreak': sessionsUntilLongBreak,
      };

  /// Decodes from [json], clamping each field to its valid range and falling
  /// back to the canonical default for any missing or non-int value.
  factory TimerConfig.fromJson(Map<String, dynamic> json) {
    const defaults = TimerConfig.defaults();

    int parseMinutes(String key, int defaultMinutes, int min, int max) {
      final raw = json[key];
      if (raw is! int) return defaultMinutes;
      return raw.clamp(min, max);
    }

    final workMinutes = parseMinutes(
      'workMinutes',
      defaults.workDuration.inMinutes,
      minWorkMinutes,
      maxWorkMinutes,
    );
    final shortBreakMinutes = parseMinutes(
      'shortBreakMinutes',
      defaults.shortBreakDuration.inMinutes,
      minShortBreakMinutes,
      maxShortBreakMinutes,
    );
    final longBreakMinutes = parseMinutes(
      'longBreakMinutes',
      defaults.longBreakDuration.inMinutes,
      minLongBreakMinutes,
      maxLongBreakMinutes,
    );

    final rawSessions = json['sessionsUntilLongBreak'];
    final sessions = rawSessions is int
        ? rawSessions.clamp(
            minSessionsUntilLongBreak,
            maxSessionsUntilLongBreak,
          )
        : defaults.sessionsUntilLongBreak;

    return TimerConfig(
      workDuration: Duration(minutes: workMinutes),
      shortBreakDuration: Duration(minutes: shortBreakMinutes),
      longBreakDuration: Duration(minutes: longBreakMinutes),
      sessionsUntilLongBreak: sessions,
    );
  }

  // ---------------------------------------------------------------------------
  // copyWith / equality / toString
  // ---------------------------------------------------------------------------

  TimerConfig copyWith({
    Duration? workDuration,
    Duration? shortBreakDuration,
    Duration? longBreakDuration,
    int? sessionsUntilLongBreak,
  }) {
    return TimerConfig(
      workDuration: workDuration ?? this.workDuration,
      shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      sessionsUntilLongBreak:
          sessionsUntilLongBreak ?? this.sessionsUntilLongBreak,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimerConfig &&
        other.workDuration == workDuration &&
        other.shortBreakDuration == shortBreakDuration &&
        other.longBreakDuration == longBreakDuration &&
        other.sessionsUntilLongBreak == sessionsUntilLongBreak;
  }

  @override
  int get hashCode => Object.hash(
        workDuration,
        shortBreakDuration,
        longBreakDuration,
        sessionsUntilLongBreak,
      );

  @override
  String toString() =>
      'TimerConfig(workDuration: $workDuration, '
      'shortBreakDuration: $shortBreakDuration, '
      'longBreakDuration: $longBreakDuration, '
      'sessionsUntilLongBreak: $sessionsUntilLongBreak)';
}
