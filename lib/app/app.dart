import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/preferences/preferences_providers.dart';
import '../core/theme/app_theme.dart';
import '../features/focus/presentation/break_presenter.dart';
import '../l10n/app_localizations.dart';

class MainApp extends ConsumerWidget {
  const MainApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
      builder: (context, child) => BreakPresenter(child: child!),
    );
  }
}
