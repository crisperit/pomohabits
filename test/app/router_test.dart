import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/app/app.dart';
import 'package:pomohabits/app/router.dart';
import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/core/supabase/auth_providers.dart';
import 'package:pomohabits/features/auth/presentation/sign_in_page.dart';
import 'package:pomohabits/features/home/presentation/home_page.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('signed-out cold boot lands on SignInPage', (tester) async {
    final controller = StreamController<AuthState>();
    addTearDown(controller.close);

    final router = buildRouter(
      authStateStream: controller.stream,
      currentSessionLookup: () => null,
    );

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          supabaseClientProvider.overrideWith((ref) => _StubClient()),
        ],
        child: MainApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('emitting a session redirects to HomePage', (tester) async {
    final controller = StreamController<AuthState>();
    addTearDown(controller.close);

    Session? session;
    final router = buildRouter(
      authStateStream: controller.stream,
      currentSessionLookup: () => session,
    );

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          supabaseClientProvider.overrideWith((ref) => _StubClient()),
        ],
        child: MainApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SignInPage), findsOneWidget);

    session = _FakeSession();
    controller.add(AuthState(AuthChangeEvent.signedIn, session));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);
  });
}

class _FakeSession extends Session {
  _FakeSession()
      : super(
          accessToken: 'fake-access',
          tokenType: 'bearer',
          user: const User(
            id: 'fake-user',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2024-01-01T00:00:00.000Z',
          ),
        );
}

// ---------------------------------------------------------------------------
// Minimal stubs to satisfy supabaseClientProvider without Supabase.initialize.
// Mirrors the pattern from test/core/supabase/auth_providers_test.dart.
// ---------------------------------------------------------------------------

class _StubClient implements SupabaseClient {
  @override
  GoTrueClient get auth => _StubAuth();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuth implements GoTrueClient {
  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
