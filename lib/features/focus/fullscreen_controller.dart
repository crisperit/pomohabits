import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

// ---------------------------------------------------------------------------
// Abstract seam
// ---------------------------------------------------------------------------

/// Controls OS-level fullscreen on break entry and exit.
///
/// Implementations differ per platform. The no-op variant is used in tests
/// so the widget layer never calls real platform plugins under flutter_test.
abstract class FullscreenController {
  Future<void> enter();
  Future<void> exit();
}

// ---------------------------------------------------------------------------
// Real implementation
// ---------------------------------------------------------------------------

class _RealFullscreenController implements FullscreenController {
  @override
  Future<void> enter() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      await windowManager.setFullScreen(true);
    } else if (!kIsWeb && Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    // All other platforms: no-op.
  }

  @override
  Future<void> exit() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      await windowManager.setFullScreen(false);
    } else if (!kIsWeb && Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    // All other platforms: no-op.
  }
}

// ---------------------------------------------------------------------------
// No-op for tests
// ---------------------------------------------------------------------------

/// A no-op [FullscreenController] used as the test default.
///
/// Override [fullscreenControllerProvider] with this in [ProviderScope] so
/// widget tests never invoke real platform plugins.
class NoopFullscreenController implements FullscreenController {
  @override
  Future<void> enter() => Future.value();

  @override
  Future<void> exit() => Future.value();
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provides the active [FullscreenController]. Override in tests with
/// [NoopFullscreenController] (or a recording fake) via [ProviderScope].
final fullscreenControllerProvider = Provider<FullscreenController>(
  (ref) => _RealFullscreenController(),
);
