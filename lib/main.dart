import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/error_app.dart';
import 'app/router.dart';
import 'core/preferences/preferences_providers.dart';
import 'core/supabase/supabase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeSupabase();
  } on SupabaseEnvException catch (e) {
    runApp(ErrorApp(message: e.message));
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final router = buildRouter();

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MainApp(router: router),
  ));
}
