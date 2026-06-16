import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/supabase/auth_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/auth_controller.dart';
import '../../settings/presentation/settings_dialog.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(currentSessionProvider);
    final name = session?.user.userMetadata?['full_name'] as String? ??
        session?.user.email ??
        '';

    // Show a SnackBar when signOut lands in an error state so the user knows
    // the action failed (session was not cleared).
    ref.listen<AsyncValue<void>>(authControllerProvider, (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authErrorUnexpected)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: l10n.homeHabitsTooltip,
            onPressed: () => unawaited(context.push(routeHabits)),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.authSignOut,
            // signOut is fire-and-forget: the router redirect (F-01) returns
            // the user to /sign-in once the session clears via the auth stream.
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
          ),
        ],
      ),
      body: Center(child: Text(l10n.homeGreeting(name))),
    );
  }
}
