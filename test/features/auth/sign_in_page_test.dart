import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/core/preferences/preferences_providers.dart';
import 'package:pomohabits/core/supabase/auth_providers.dart';
import 'package:pomohabits/features/auth/presentation/sign_in_page.dart';
import 'package:pomohabits/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test harness helpers
// ---------------------------------------------------------------------------

/// Pumps [SignInPage] in a minimal [MaterialApp] with full l10n + Riverpod.
Future<void> _pumpSignInPage(
  WidgetTester tester, {
  required _StubClient stubClient,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(stubClient),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SignInPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SignInPage', () {
    testWidgets('sign-in mode shows email and password fields only',
        (tester) async {
      final stub = _StubClient(auth: _StubAuth());
      await _pumpSignInPage(tester, stubClient: stub);

      expect(find.byKey(const ValueKey('authEmailField')), findsOneWidget);
      expect(find.byKey(const ValueKey('authPasswordField')), findsOneWidget);
      expect(find.byKey(const ValueKey('authNameField')), findsNothing);
      expect(
          find.byKey(const ValueKey('authConfirmPasswordField')), findsNothing);
    });

    testWidgets('toggling to sign-up reveals name and confirm-password fields',
        (tester) async {
      final stub = _StubClient(auth: _StubAuth());
      await _pumpSignInPage(tester, stubClient: stub);

      // Name and confirm-password absent in sign-in mode.
      expect(find.byKey(const ValueKey('authNameField')), findsNothing);
      expect(
          find.byKey(const ValueKey('authConfirmPasswordField')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('authToggleButton')));
      await tester.pumpAndSettle();

      // Both fields visible after toggling to sign-up.
      expect(find.byKey(const ValueKey('authNameField')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('authConfirmPasswordField')), findsOneWidget);
    });

    testWidgets(
        'submitting with empty email and short password shows validation errors '
        'and does NOT call the client', (tester) async {
      final auth = _StubAuth();
      final stub = _StubClient(auth: auth);
      await _pumpSignInPage(tester, stubClient: stub);

      await tester.tap(find.byKey(const ValueKey('authSubmitButton')));
      await tester.pumpAndSettle();

      // Validation messages are shown.
      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

      // The client was NOT called.
      expect(auth.signInCallCount, 0);
    });

    testWidgets(
        'stubbed AuthException on sign-in renders the message inline',
        (tester) async {
      final auth = _StubAuth(signInError: const AuthException('bad creds'));
      final stub = _StubClient(auth: auth);
      await _pumpSignInPage(tester, stubClient: stub);

      await tester.enterText(
          find.byKey(const ValueKey('authEmailField')), 'user@example.com');
      await tester.enterText(
          find.byKey(const ValueKey('authPasswordField')), 'wrongpassword');

      await tester.tap(find.byKey(const ValueKey('authSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.text('bad creds'), findsOneWidget);
    });

    testWidgets(
        'submit button shows spinner and is disabled while call is in flight',
        (tester) async {
      final completer = Completer<AuthResponse>();
      final auth = _StubAuth(signInCompleter: completer);
      final stub = _StubClient(auth: auth);
      await _pumpSignInPage(tester, stubClient: stub);

      await tester.enterText(
          find.byKey(const ValueKey('authEmailField')), 'user@example.com');
      await tester.enterText(
          find.byKey(const ValueKey('authPasswordField')), 'password123');

      // Tap submit - do NOT settle; the stub is gated by the completer.
      await tester.tap(find.byKey(const ValueKey('authSubmitButton')));
      await tester.pump();

      // Spinner is visible.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Button is disabled (onPressed is null).
      final button = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('authSubmitButton')),
      );
      expect(button.onPressed, isNull);

      // Complete the future so the test teardown is clean.
      completer.complete(AuthResponse(session: null));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'sign-up with null session transitions to awaiting-confirmation',
        (tester) async {
      final auth = _StubAuth(
        signUpResponse: AuthResponse(
          session: null,
          user: const User(
            id: 'u1',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ),
      );
      final stub = _StubClient(auth: auth);
      await _pumpSignInPage(tester, stubClient: stub);

      // Toggle to sign-up mode.
      await tester.tap(find.byKey(const ValueKey('authToggleButton')));
      await tester.pumpAndSettle();

      // Fill valid values.
      await tester.enterText(
          find.byKey(const ValueKey('authNameField')), 'Test User');
      await tester.enterText(
          find.byKey(const ValueKey('authEmailField')), 'test@example.com');
      await tester.enterText(
          find.byKey(const ValueKey('authPasswordField')), 'password123');
      await tester.enterText(
          find.byKey(const ValueKey('authConfirmPasswordField')), 'password123');

      await tester.tap(find.byKey(const ValueKey('authSubmitButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('authResendButton')), findsOneWidget);
      expect(find.text('Check your email'), findsOneWidget);

      // Verify the page passed the entered name as full_name metadata.
      expect(auth.lastSignUpData, containsPair('full_name', 'Test User'));
    });
  });
}

// ---------------------------------------------------------------------------
// Hand-rolled stubs - no mocking library, mirrors auth_controller_test.dart
// ---------------------------------------------------------------------------

class _StubClient implements SupabaseClient {
  _StubClient({required this.auth});

  @override
  final _StubAuth auth;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuth implements GoTrueClient {
  _StubAuth({
    this.signInError,
    this.signInCompleter,
    this.signUpResponse,
  });

  final AuthException? signInError;

  /// When set, signInWithPassword waits for this completer - used to
  /// hold the call in-flight so the test can assert the loading state.
  final Completer<AuthResponse>? signInCompleter;

  final AuthResponse? signUpResponse;

  int signInCallCount = 0;
  int signUpCallCount = 0;

  /// Records the `data` map passed to the most recent [signUp] call.
  Map<String, dynamic>? lastSignUpData;

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    signInCallCount++;
    if (signInCompleter != null) return signInCompleter!.future;
    if (signInError != null) throw signInError!;
    return AuthResponse(session: null);
  }

  @override
  Future<AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    signUpCallCount++;
    lastSignUpData = data;
    return signUpResponse ?? AuthResponse(session: null);
  }

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Session? get currentSession => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

