import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/preferences_providers.dart';
import '../../../features/focus/timer_config.dart';
import '../../../l10n/app_localizations.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _workCtrl;
  late final TextEditingController _shortBreakCtrl;
  late final TextEditingController _longBreakCtrl;
  late final TextEditingController _sessionsCtrl;

  late final FocusNode _workFocus;
  late final FocusNode _shortBreakFocus;
  late final FocusNode _longBreakFocus;
  late final FocusNode _sessionsFocus;

  @override
  void initState() {
    super.initState();
    final config = ref.read(timerConfigProvider);
    _workCtrl = TextEditingController(
      text: config.workDuration.inMinutes.toString(),
    );
    _shortBreakCtrl = TextEditingController(
      text: config.shortBreakDuration.inMinutes.toString(),
    );
    _longBreakCtrl = TextEditingController(
      text: config.longBreakDuration.inMinutes.toString(),
    );
    _sessionsCtrl = TextEditingController(
      text: config.sessionsUntilLongBreak.toString(),
    );

    _workFocus = FocusNode()..addListener(() => _onFocusLost(_workFocus, _workCtrl));
    _shortBreakFocus = FocusNode()
      ..addListener(() => _onFocusLost(_shortBreakFocus, _shortBreakCtrl));
    _longBreakFocus = FocusNode()
      ..addListener(() => _onFocusLost(_longBreakFocus, _longBreakCtrl));
    _sessionsFocus = FocusNode()
      ..addListener(() => _onFocusLost(_sessionsFocus, _sessionsCtrl));
  }

  @override
  void dispose() {
    _workCtrl.dispose();
    _shortBreakCtrl.dispose();
    _longBreakCtrl.dispose();
    _sessionsCtrl.dispose();
    _workFocus.dispose();
    _shortBreakFocus.dispose();
    _longBreakFocus.dispose();
    _sessionsFocus.dispose();
    super.dispose();
  }

  String? _validateField(String? value, int min, int max, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.timerRangeError(min, max);
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < min || parsed > max) {
      return l10n.timerRangeError(min, max);
    }
    return null;
  }

  /// Persists the current form values only when all four fields are valid.
  void _persistIfValid() {
    if (_formKey.currentState!.validate()) {
      final config = ref.read(timerConfigProvider);
      final newConfig = config.copyWith(
        workDuration: Duration(minutes: int.parse(_workCtrl.text)),
        shortBreakDuration: Duration(minutes: int.parse(_shortBreakCtrl.text)),
        longBreakDuration: Duration(minutes: int.parse(_longBreakCtrl.text)),
        sessionsUntilLongBreak: int.parse(_sessionsCtrl.text),
      );
      unawaited(ref.read(timerConfigProvider.notifier).set(newConfig));
    }
  }

  /// Called by each FocusNode listener; only persists on the focus-lost edge.
  void _onFocusLost(FocusNode node, TextEditingController ctrl) {
    if (!node.hasFocus) {
      _persistIfValid();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.timerSectionLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('timerWorkField'),
                    controller: _workCtrl,
                    focusNode: _workFocus,
                    decoration: InputDecoration(labelText: l10n.timerWorkLabel),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _validateField(
                      v,
                      TimerConfig.minWorkMinutes,
                      TimerConfig.maxWorkMinutes,
                      l10n,
                    ),
                    onFieldSubmitted: (_) => _persistIfValid(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('timerShortBreakField'),
                    controller: _shortBreakCtrl,
                    focusNode: _shortBreakFocus,
                    decoration: InputDecoration(labelText: l10n.timerShortBreakLabel),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _validateField(
                      v,
                      TimerConfig.minShortBreakMinutes,
                      TimerConfig.maxShortBreakMinutes,
                      l10n,
                    ),
                    onFieldSubmitted: (_) => _persistIfValid(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('timerLongBreakField'),
                    controller: _longBreakCtrl,
                    focusNode: _longBreakFocus,
                    decoration: InputDecoration(labelText: l10n.timerLongBreakLabel),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _validateField(
                      v,
                      TimerConfig.minLongBreakMinutes,
                      TimerConfig.maxLongBreakMinutes,
                      l10n,
                    ),
                    onFieldSubmitted: (_) => _persistIfValid(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('timerSessionsField'),
                    controller: _sessionsCtrl,
                    focusNode: _sessionsFocus,
                    decoration: InputDecoration(labelText: l10n.timerSessionsLabel),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _validateField(
                      v,
                      TimerConfig.minSessionsUntilLongBreak,
                      TimerConfig.maxSessionsUntilLongBreak,
                      l10n,
                    ),
                    onFieldSubmitted: (_) => _persistIfValid(),
                  ),
                ],
              ),
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
