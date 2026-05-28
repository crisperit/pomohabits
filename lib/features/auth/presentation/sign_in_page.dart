import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_dialog.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
          ),
        ],
      ),
      body: Center(child: Text(AppLocalizations.of(context)!.signInPlaceholder)),
    );
  }
}
