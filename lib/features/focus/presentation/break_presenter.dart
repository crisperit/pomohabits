import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../focus_session.dart';
import '../focus_session_controller.dart';
import '../fullscreen_controller.dart';
import 'break_screen.dart';

/// Mounts above the router content and overlays [BreakScreen] whenever the
/// focus session enters a break phase.
///
/// Use this as the [MaterialApp.router] `builder` wrapper so the break surface
/// appears over ANY current screen with no Navigator-context dependency and no
/// push/pop race:
///
/// ```dart
/// builder: (context, child) => BreakPresenter(child: child!),
/// ```
///
/// The overlay is a [Stack] that covers the app when `phase.isBreak` and
/// disappears when the phase returns to focus -- driven by the controller
/// state, not any page's build method.
class BreakPresenter extends ConsumerStatefulWidget {
  const BreakPresenter({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BreakPresenter> createState() => _BreakPresenterState();
}

class _BreakPresenterState extends ConsumerState<BreakPresenter> {
  /// Captured at break-entry so [BreakScreen] keeps a stable `isLongBreak`
  /// value even if the phase object changes during the break.
  bool _isLongBreak = false;

  @override
  void initState() {
    super.initState();
    // Capture initial phase in case we resume mid-break.
    final session = ref.read(focusSessionControllerProvider);
    if (session.phase.isBreak) {
      _isLongBreak = session.isLongBreak;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for phase transitions to drive fullscreen enter/exit.
    ref.listen<FocusPhase>(
      focusSessionControllerProvider.select((s) => s.phase),
      (previous, next) {
        final fullscreen = ref.read(fullscreenControllerProvider);
        if (next.isBreak && !(previous?.isBreak ?? false)) {
          // Entered a break phase.
          setState(() {
            _isLongBreak =
                ref.read(focusSessionControllerProvider).isLongBreak;
          });
          // Fire-and-forget per unawaited_futures convention (Future discarded
          // intentionally -- fullscreen toggling is best-effort).
          // ignore: discarded_futures
          fullscreen.enter();
        } else if (!(next.isBreak) && (previous?.isBreak ?? false)) {
          // Left a break phase.
          // ignore: discarded_futures
          fullscreen.exit();
        }
      },
    );

    final isBreak = ref.watch(
      focusSessionControllerProvider.select((s) => s.isBreak),
    );

    return Stack(
      children: [
        widget.child,
        if (isBreak)
          Positioned.fill(
            child: BreakScreen(isLongBreak: _isLongBreak),
          ),
      ],
    );
  }
}
