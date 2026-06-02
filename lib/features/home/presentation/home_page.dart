import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.authSignOut,
            // signOut is fire-and-forget: the F-01 router redirect returns the
            // user to /sign-in once the session clears via the auth stream.
            // TODO(s-01): surface signOut errors to the user (controller captures them in AsyncValue, but Home has no listener).
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
