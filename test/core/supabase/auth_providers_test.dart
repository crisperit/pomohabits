import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:taskodoro/core/supabase/auth_providers.dart';

// SupabaseClient and GoTrueClient are non-sealed concrete classes, so they
// can be stubbed via `implements` + `noSuchMethod`. The constructors start
// network connections, so we must never call super - `implements` avoids that.

void main() {
  group('currentSessionProvider', () {
    test('returns null before the auth stream emits', () {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          authStateChangesProvider.overrideWith(
            (ref) => controller.stream,
          ),
          supabaseClientProvider.overrideWith(
            (ref) => _StubClient(initialSession: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentSessionProvider), isNull);
    });

    test('returns the session from a stream emission', () async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          authStateChangesProvider.overrideWith(
            (ref) => controller.stream,
          ),
          supabaseClientProvider.overrideWith(
            (ref) => _StubClient(initialSession: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Keep the provider alive so it can react to stream emissions.
      container.listen(currentSessionProvider, (_, _) {});

      final fakeSession = _FakeSession();
      controller.add(AuthState(AuthChangeEvent.signedIn, fakeSession));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(currentSessionProvider), same(fakeSession));
    });
  });
}

class _StubClient implements SupabaseClient {
  _StubClient({required this.initialSession});
  final Session? initialSession;

  @override
  GoTrueClient get auth => _StubAuth(initialSession);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuth implements GoTrueClient {
  _StubAuth(this._session);
  final Session? _session;

  @override
  Session? get currentSession => _session;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

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
