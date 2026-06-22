import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/auth_providers.dart';
import 'habit.dart';

const _rpcAddHabit = 'add_habit';
const _rpcListHabits = 'list_habits';
const _rpcCompleteHabit = 'complete_habit';
const _rpcUpdateHabit = 'update_habit';
const _rpcDeleteHabit = 'delete_habit';
const _channelHabitsPrefix = 'public:habits:';

class HabitsRepository {
  HabitsRepository(this._client);

  final SupabaseClient _client;

  Future<Habit> addHabit({
    required String name,
    required HabitCategory category,
    required HabitBreakWindow applicableBreakWindow,
    required bool alwaysShown,
    String? icon,
  }) async {
    final data = await _client.rpc(
      _rpcAddHabit,
      params: {
        'p_name': name,
        'p_category': category.wire,
        'p_applicable_break_window': applicableBreakWindow.wire,
        'p_always_shown': alwaysShown,
        'p_icon': icon,
      },
    );
    if (data is! Map<String, dynamic>) {
      throw StateError(
        'add_habit returned an unexpected response shape: ${data.runtimeType}',
      );
    }
    return Habit.fromRow(data);
  }

  Future<List<Habit>> fetchHabits({String timezone = 'UTC'}) async {
    final data = await _client.rpc(
      _rpcListHabits,
      params: {'p_timezone': timezone},
    );
    if (data is! List) {
      throw StateError(
        'list_habits returned an unexpected response shape: ${data.runtimeType}',
      );
    }
    return data
        .map((r) => Habit.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> completeHabit(String habitId) async {
    try {
      await _client.rpc(
        _rpcCompleteHabit,
        params: {'p_habit_id': habitId},
      );
    } on PostgrestException catch (e) {
      debugPrint('completeHabit failed: $e');
      rethrow;
    }
  }

  Future<Habit> updateHabit({
    required String id,
    required String name,
    required HabitCategory category,
    required HabitBreakWindow applicableBreakWindow,
    required bool alwaysShown,
    String? icon,
  }) async {
    try {
      final data = await _client.rpc(
        _rpcUpdateHabit,
        params: {
          'p_id': id,
          'p_name': name,
          'p_category': category.wire,
          'p_applicable_break_window': applicableBreakWindow.wire,
          'p_always_shown': alwaysShown,
          'p_icon': icon,
        },
      );
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'update_habit returned an unexpected response shape: ${data.runtimeType}',
        );
      }
      return Habit.fromRow(data);
    } on PostgrestException catch (e) {
      debugPrint('updateHabit failed: $e');
      rethrow;
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      await _client.rpc(
        _rpcDeleteHabit,
        params: {'p_id': id},
      );
    } on PostgrestException catch (e) {
      debugPrint('deleteHabit failed: $e');
      rethrow;
    }
  }

  /// Returns a stream that emits a signal whenever a row in the `habits` table
  /// changes for [userId]. Uses the lower-level realtime channel notification
  /// API: no `.from('habits')` table read is performed; all data still flows
  /// through [fetchHabits] (RPC-only contract).
  Stream<void> habitChanges({required String userId}) {
    final controller = StreamController<void>();

    final channel = _client
        .channel('$_channelHabitsPrefix$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'habits',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => controller.add(null),
        )
        .subscribe();

    controller.onCancel = () async {
      try {
        await _client.removeChannel(channel);
      } on Exception catch (e) {
        debugPrint('habitChanges: removeChannel failed: $e');
      }
    };

    return controller.stream;
  }
}

final habitsRepositoryProvider = Provider<HabitsRepository>(
  (ref) => HabitsRepository(ref.watch(supabaseClientProvider)),
);
