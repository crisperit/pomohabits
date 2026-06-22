import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/focus/timer_config.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    final previous = state;
    state = mode;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_key, mode.name);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  static const _key = 'locale';

  @override
  Locale? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    return Locale(raw);
  }

  Future<void> set(Locale? locale) async {
    final previous = state;
    state = locale;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (locale == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, locale.languageCode);
      }
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class TimerConfigNotifier extends Notifier<TimerConfig> {
  static const _key = 'timer_config';

  @override
  TimerConfig build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const TimerConfig.defaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const TimerConfig.defaults();
      return TimerConfig.fromJson(decoded);
    } catch (_) {
      return const TimerConfig.defaults();
    }
  }

  Future<void> set(TimerConfig config) async {
    final previous = state;
    state = config;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_key, jsonEncode(config.toJson()));
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final timerConfigProvider =
    NotifierProvider<TimerConfigNotifier, TimerConfig>(TimerConfigNotifier.new);
