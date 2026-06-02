import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:taskodoro/core/preferences/preferences_providers.dart';
import 'package:taskodoro/core/supabase/auth_providers.dart';
import 'package:taskodoro/features/home/presentation/home_page.dart';
import 'package:taskodoro/l10n/app_localizations.dart';

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
