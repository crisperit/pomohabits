import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/error_app.dart';
import 'core/preferences/preferences_providers.dart';
import 'core/supabase/supabase_init.dart';
import 'features/auth/presentation/sign_in_page.dart';
import 'features/home/presentation/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeSupabase();
  } on SupabaseEnvException catch (e) {
    runApp(ErrorApp(message: e.message));
    return;
  }

  final prefs = await SharedPreferences.getInstance();

  // Phase 4 replaces this with buildRouter() from app/router.dart.
  final router = GoRouter(
    initialLocation: '/sign-in',
    routes: [
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInPage()),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
    ],
  );

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MainApp(router: router),
  ));
}
