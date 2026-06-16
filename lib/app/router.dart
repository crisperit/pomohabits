import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/sign_in_page.dart';
import '../features/habits/presentation/add_habit_page.dart';
import '../features/habits/presentation/habits_page.dart';
import '../features/home/presentation/home_page.dart';

const routeSignIn = '/sign-in';
const routeHome = '/home';
const routeHabits = '/habits';
const routeAddHabit = '/habits/new';

GoRouter buildRouter({
  Stream<AuthState>? authStateStream,
  Session? Function()? currentSessionLookup,
}) {
  final stream =
      authStateStream ?? Supabase.instance.client.auth.onAuthStateChange;
  final lookup =
      currentSessionLookup ?? (() => Supabase.instance.client.auth.currentSession);

  return GoRouter(
    initialLocation: routeSignIn,
    refreshListenable: GoRouterRefreshStream(stream),
    redirect: (context, state) {
      final session = lookup();
      final goingToSignIn = state.matchedLocation == routeSignIn;
      if (session == null && !goingToSignIn) return routeSignIn;
      if (session != null && goingToSignIn) return routeHome;
      return null;
    },
    routes: [
      GoRoute(path: routeSignIn, builder: (context, state) => const SignInPage()),
      GoRoute(path: routeHome, builder: (context, state) => const HomePage()),
      GoRoute(path: routeHabits, builder: (context, state) => const HabitsPage()),
      GoRoute(path: routeAddHabit, builder: (context, state) => const AddHabitPage()),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
    notifyListeners();
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
