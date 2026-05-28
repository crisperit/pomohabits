import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/preferences_providers.dart';
import '../../../l10n/app_localizations.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return AlertDialog(
      title: Text(l10n.settingsTitle),
      content: SingleChildScrollView(
        child: Column(
          children: [
            DropdownMenu<ThemeMode>(
              initialSelection: themeMode,
              label: Text(l10n.themeLabel),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: [
                DropdownMenuEntry(value: ThemeMode.system, label: l10n.themeSystem),
                DropdownMenuEntry(value: ThemeMode.light, label: l10n.themeLight),
                DropdownMenuEntry(value: ThemeMode.dark, label: l10n.themeDark),
              ],
              onSelected: (v) {
                if (v != null) unawaited(ref.read(themeModeProvider.notifier).set(v));
              },
            ),
            const SizedBox(height: 16),
            DropdownMenu<Locale?>(
              initialSelection: locale,
              label: Text(l10n.localeLabel),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: [
                DropdownMenuEntry<Locale?>(value: null, label: l10n.localeSystem),
                DropdownMenuEntry<Locale?>(value: const Locale('en'), label: l10n.localeEnglish),
                DropdownMenuEntry<Locale?>(value: const Locale('pl'), label: l10n.localePolish),
              ],
              onSelected: (v) => unawaited(ref.read(localeProvider.notifier).set(v)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
