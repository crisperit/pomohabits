import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:taskodoro/app/app.dart';
import 'package:taskodoro/app/router.dart';
import 'package:taskodoro/core/preferences/preferences_providers.dart';
import 'package:taskodoro/features/auth/presentation/sign_in_page.dart';
import 'package:taskodoro/features/home/presentation/home_page.dart';

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
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
