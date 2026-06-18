enum HabitCategory {
  oneTime,
  daily,
  unlimited;

  String get wire => switch (this) {
        HabitCategory.oneTime => 'one_time',
        HabitCategory.daily => 'daily',
        HabitCategory.unlimited => 'unlimited',
      };

  static HabitCategory fromWire(String value) => switch (value) {
        'one_time' => HabitCategory.oneTime,
        'daily' => HabitCategory.daily,
        'unlimited' => HabitCategory.unlimited,
        _ => throw ArgumentError.value(
            value,
            'value',
            'Unknown HabitCategory wire value',
          ),
      };
}

enum HabitBreakWindow {
  short,
  long,
  both;

  String get wire => switch (this) {
        HabitBreakWindow.short => 'short',
        HabitBreakWindow.long => 'long',
        HabitBreakWindow.both => 'both',
      };

  static HabitBreakWindow fromWire(String value) => switch (value) {
        'short' => HabitBreakWindow.short,
        'long' => HabitBreakWindow.long,
        'both' => HabitBreakWindow.both,
        _ => throw ArgumentError.value(
            value,
            'value',
            'Unknown HabitBreakWindow wire value',
          ),
      };
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.category,
    required this.applicableBreakWindow,
    required this.alwaysShown,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.completedToday = false,
    this.completedEver = false,
  });

  final String id;
  final String name;
  final HabitCategory category;
  final HabitBreakWindow applicableBreakWindow;
  final bool alwaysShown;
  final String? icon;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool completedToday;
  final bool completedEver;

  factory Habit.fromRow(Map<String, dynamic> row) {
    return Habit(
      id: row['id'] as String,
      name: row['name'] as String,
      category: HabitCategory.fromWire(row['category'] as String),
      applicableBreakWindow:
          HabitBreakWindow.fromWire(row['applicable_break_window'] as String),
      alwaysShown: row['always_shown'] as bool,
      icon: row['icon'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      completedToday: row['completed_today'] as bool? ?? false,
      completedEver: row['completed_ever'] as bool? ?? false,
    );
  }
}
