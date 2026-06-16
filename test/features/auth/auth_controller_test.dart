import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pomohabits/core/supabase/auth_providers.dart';
import 'package:pomohabits/features/auth/auth_controller.dart';

void main() {
  group('AuthController', () {
    test('signIn success leaves state without error', () async {
      final stub = _StubClient(auth: _StubAuth());
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => stub),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'a@b.com', password: 'secret');

      expect(container.read(authControllerProvider).hasError, isFalse);
    });

    test('signIn failure puts AuthException into state', () async {
      final stub = _StubClient(
        auth: _StubAuth(
          signInError: const AuthException('boom'),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => stub),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'a@b.com', password: 'wrong');

      final state = container.read(authControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error as AuthException).message, 'boom');
    });

    test('signUp with non-null session returns signedIn', () async {
      final stub = _StubClient(
        auth: _StubAuth(signUpSession: _FakeSession()),
      );
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => stub),
        ],
      );
      addTearDown(container.dispose);

      final outcome = await container
          .read(authControllerProvider.notifier)
          .signUp(name: 'Alice', email: 'a@b.com', password: 'secret');

      expect(outcome, AuthSignUpOutcome.signedIn);
    });

    test('signUp with null session returns awaitingConfirmation', () async {
      final stub = _StubClient(
        auth: _StubAuth(signUpSession: null),
      );
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => stub),
        ],
      );
      addTearDown(container.dispose);

      final outcome = await container
          .read(authControllerProvider.notifier)
          .signUp(name: 'Alice', email: 'a@b.com', password: 'secret');

      expect(outcome, AuthSignUpOutcome.awaitingConfirmation);
    });

    test('signUp passes full_name in data and null emailRedirectTo on Linux',
        () async {
      final auth = _StubAuth();
      final stub = _StubClient(auth: auth);
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => stub),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .signUp(name: 'Alice', email: 'a@b.com', password: 'secret');

      expect(auth.lastSignUpData, equals({'full_name': 'Alice'}));
      expect(auth.lastSignUpEmailRedirectTo, isNull);
    });

    test('signOut calls through to the auth client', () async {
      final auth = _StubAuth();
      final stub = _StubClient(auth: auth);
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => stub),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).signOut();

      expect(auth.signOutCalled, isTrue);
    });

    test('signUp failure returns null and puts AuthException into state',
        () async {
      final stub = _StubClient(
        auth: _StubAuth(signUpError: const AuthException('signup boom')),
      );
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => stub),
        ],
      );
      addTearDown(container.dispose);

      final outcome = await container
          .read(authControllerProvider.notifier)
          .signUp(name: 'Alice', email: 'a@b.com', password: 'secret');

      final state = container.read(authControllerProvider);
      expect(outcome, isNull);
      expect(state.hasError, isTrue);
      expect((state.error as AuthException).message, 'signup boom');
    });

    test('resendConfirmation success leaves state without error and records call',
        () async {
      final auth = _StubAuth();
      final stub = _StubClient(auth: auth);
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => stub),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .resendConfirmation(email: 'a@b.com');

      expect(container.read(authControllerProvider).hasError, isFalse);
      expect(auth.lastResendType, OtpType.signup);
      expect(auth.lastResendEmail, 'a@b.com');
      expect(auth.lastResendEmailRedirectTo, isNull);
    });

    test('resendConfirmation failure puts AuthException into state', () async {
      final stub = _StubClient(
        auth: _StubAuth(resendError: const AuthException('resend boom')),
      );
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => stub),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .resendConfirmation(email: 'a@b.com');

      final state = container.read(authControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error as AuthException).message, 'resend boom');
    });
  });
}

// ---------------------------------------------------------------------------
// Hand-rolled stubs - no mocking library, mirrors auth_providers_test.dart
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
    this.signUpSession,
    this.signUpError,
    this.resendError,
  });

  final AuthException? signInError;

  /// If null, signUp returns an AuthResponse with no session (confirmation pending).
  final Session? signUpSession;

  /// If set, signUp throws this error instead of returning a response.
  final AuthException? signUpError;

  /// If set, resend throws this error instead of returning normally.
  final AuthException? resendError;

  Map<String, dynamic>? lastSignUpData;
  String? lastSignUpEmailRedirectTo;
  bool signOutCalled = false;
  OtpType? lastResendType;
  String? lastResendEmail;
  String? lastResendEmailRedirectTo;

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    if (signInError != null) throw signInError!;
    return AuthResponse(session: _FakeSession());
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
    if (signUpError != null) throw signUpError!;
    lastSignUpData = data;
    lastSignUpEmailRedirectTo = emailRedirectTo;
    return AuthResponse(session: signUpSession);
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOutCalled = true;
  }

  @override
  Future<ResendResponse> resend({
    String? email,
    String? phone,
    required OtpType type,
    String? emailRedirectTo,
    String? captchaToken,
  }) async {
    if (resendError != null) throw resendError!;
    lastResendType = type;
    lastResendEmail = email;
    lastResendEmailRedirectTo = emailRedirectTo;
    return ResendResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
