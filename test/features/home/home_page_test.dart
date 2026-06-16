import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/app/router.dart';
import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/core/supabase/auth_providers.dart';
import 'package:pomohabits/features/home/presentation/home_page.dart';
import 'package:pomohabits/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test harness helpers
// ---------------------------------------------------------------------------

Future<void> _pumpHomePage(
  WidgetTester tester, {
  required _FakeSession session,
  required _StubClient stubClient,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSessionProvider.overrideWithValue(session),
        supabaseClientProvider.overrideWith((ref) => stubClient),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HomePage', () {
    testWidgets('greeting shows the full_name from session metadata',
        (tester) async {
      final session = _FakeSession(
        fullName: 'Test User',
        email: 'test@example.com',
      );
      final stub = _StubClient(auth: _StubAuth());
      await _pumpHomePage(tester, session: session, stubClient: stub);

      // homeGreeting renders "Hello, Test User" in en locale.
      expect(find.text('Hello, Test User'), findsOneWidget);
    });

    testWidgets('sign-out action is present and calls signOut on the stub',
        (tester) async {
      final session = _FakeSession(
        fullName: 'Test User',
        email: 'test@example.com',
      );
      final auth = _StubAuth();
      final stub = _StubClient(auth: auth);
      await _pumpHomePage(tester, session: session, stubClient: stub);

      // Locate the sign-out button by its icon.
      final signOutButton = find.widgetWithIcon(IconButton, Icons.logout);
      expect(signOutButton, findsOneWidget);

      await tester.tap(signOutButton);
      await tester.pump();

      expect(auth.signOutCallCount, 1);
    });

    testWidgets(
        'Tasks button pushes /tasks so back navigation is possible',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = _FakeSession(
        fullName: 'Test User',
        email: 'test@example.com',
      );
      final stub = _StubClient(auth: _StubAuth());

      // Minimal router: /home -> HomePage, /tasks -> probe scaffold.
      // No redirect guard needed; the test starts directly at /home.
      final router = GoRouter(
        initialLocation: routeHome,
        routes: [
          GoRoute(
            path: routeHome,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: routeTasks,
            builder: (context, state) => Scaffold(
              appBar: AppBar(),
              body: const SizedBox(key: ValueKey('tasksProbe')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSessionProvider.overrideWithValue(session),
            supabaseClientProvider.overrideWith((ref) => stub),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Tasks icon button on the home AppBar.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.checklist));
      await tester.pumpAndSettle();

      // The probe scaffold is now on screen (push succeeded).
      expect(find.byKey(const ValueKey('tasksProbe')), findsOneWidget);

      // A back button is present because /tasks was pushed on top of /home.
      expect(find.byType(BackButton), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Hand-rolled stubs - no mocking library, mirrors auth_controller_test.dart
// ---------------------------------------------------------------------------

class _FakeSession extends Session {
  _FakeSession({required String fullName, required String email})
      : super(
          accessToken: 'fake-access',
          tokenType: 'bearer',
          user: User(
            id: 'fake-user',
            appMetadata: const {},
            userMetadata: {'full_name': fullName},
            aud: 'authenticated',
            createdAt: '2024-01-01T00:00:00.000Z',
            email: email,
          ),
        );
}

class _StubClient implements SupabaseClient {
  _StubClient({required this.auth});

  @override
  final _StubAuth auth;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuth implements GoTrueClient {
  int signOutCallCount = 0;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOutCallCount++;
  }

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Session? get currentSession => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
