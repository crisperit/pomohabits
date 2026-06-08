enum TaskCategory {
  oneTime,
  daily,
  unlimited;

  String get wire => switch (this) {
        TaskCategory.oneTime => 'one_time',
        TaskCategory.daily => 'daily',
        TaskCategory.unlimited => 'unlimited',
      };

  static TaskCategory fromWire(String value) => switch (value) {
        'one_time' => TaskCategory.oneTime,
        'daily' => TaskCategory.daily,
        'unlimited' => TaskCategory.unlimited,
        _ => throw ArgumentError.value(
            value,
            'value',
            'Unknown TaskCategory wire value',
          ),
      };
}

enum TaskBreakWindow {
  short,
  long,
  both;

  String get wire => switch (this) {
        TaskBreakWindow.short => 'short',
        TaskBreakWindow.long => 'long',
        TaskBreakWindow.both => 'both',
      };

  static TaskBreakWindow fromWire(String value) => switch (value) {
        'short' => TaskBreakWindow.short,
        'long' => TaskBreakWindow.long,
        'both' => TaskBreakWindow.both,
        _ => throw ArgumentError.value(
            value,
            'value',
            'Unknown TaskBreakWindow wire value',
          ),
      };
}

class Task {
  const Task({
    required this.id,
    required this.name,
    required this.category,
    required this.applicableBreakWindow,
    required this.alwaysShown,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final TaskCategory category;
  final TaskBreakWindow applicableBreakWindow;
  final bool alwaysShown;
  final String? icon;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Task.fromRow(Map<String, dynamic> row) {
    return Task(
      id: row['id'] as String,
      name: row['name'] as String,
      category: TaskCategory.fromWire(row['category'] as String),
      applicableBreakWindow:
          TaskBreakWindow.fromWire(row['applicable_break_window'] as String),
      alwaysShown: row['always_shown'] as bool,
      icon: row['icon'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
