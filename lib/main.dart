import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/error_app.dart';
import 'app/router.dart';
import 'core/preferences/preferences_providers.dart';
import 'core/supabase/supabase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window_manager on desktop only. Guarded so Android and test
  // paths are unaffected.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
  }

  try {
    await initializeSupabase();
    final prefs = await SharedPreferences.getInstance();
    final router = buildRouter();

    runApp(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MainApp(router: router),
    ));
  } on SupabaseEnvException catch (e) {
    runApp(ErrorApp(message: e.message));
  } catch (e) {
    runApp(ErrorApp(message: 'Startup failed: $e'));
  }
}
