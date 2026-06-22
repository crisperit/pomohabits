import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/auth_providers.dart';
import '../../data/habits_repository.dart';
import 'habits_controller.dart';

class HabitsRealtimeController extends Notifier<void> {
  StreamSubscription<void>? _sub;

  @override
  void build() {
    final userId = ref.watch(currentUserIdProvider);

    // Cancel any prior subscription before (re)subscribing. Riverpod re-runs
    // build() when a watched dependency changes, so this fires on each
    // user-id change (sign-in, sign-out).
    _sub?.cancel();
    _sub = null;

    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });

    if (userId == null) {
      return;
    }

    _sub = ref
        .read(habitsRepositoryProvider)
        .habitChanges(userId: userId)
        .listen(
          (_) => ref.invalidate(habitsListProvider),
          onError: (Object e) =>
              debugPrint('HabitsRealtimeController: stream error: $e'),
        );
  }
}

final habitsRealtimeControllerProvider =
    NotifierProvider<HabitsRealtimeController, void>(
  HabitsRealtimeController.new,
);
