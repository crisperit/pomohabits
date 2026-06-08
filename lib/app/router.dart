import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/sign_in_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/tasks/presentation/add_task_page.dart';
import '../features/tasks/presentation/tasks_page.dart';

const routeSignIn = '/sign-in';
const routeHome = '/home';
const routeTasks = '/tasks';
const routeAddTask = '/tasks/new';

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
      GoRoute(path: routeTasks, builder: (context, state) => const TasksPage()),
      GoRoute(path: routeAddTask, builder: (context, state) => const AddTaskPage()),
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
