import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_providers.dart';

const authCallbackUrl = 'io.taskodoro.app://auth-callback';
const metadataFullNameKey = 'full_name';

enum AuthSignUpOutcome { signedIn, awaitingConfirmation }

class AuthController extends AsyncNotifier<void> {
  late GoTrueClient _auth;

  @override
  Future<void> build() async {
    _auth = ref.watch(supabaseClientProvider).auth;
  }

  String? get _androidOnlyCallbackUrl =>
      (!kIsWeb && Platform.isAndroid) ? authCallbackUrl : null;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async {
        await _auth.signInWithPassword(email: email, password: password);
      },
    );
  }

  /// Returns null iff the call failed (state ends in AsyncError); otherwise
  /// returns the [AuthSignUpOutcome] (signedIn or awaitingConfirmation).
  Future<AuthSignUpOutcome?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard<AuthSignUpOutcome>(
      () async {
        final response = await _auth.signUp(
          email: email,
          password: password,
          data: {metadataFullNameKey: name},
          emailRedirectTo: _androidOnlyCallbackUrl,
        );
        return response.session == null
            ? AuthSignUpOutcome.awaitingConfirmation
            : AuthSignUpOutcome.signedIn;
      },
    );
    state = result.whenData((_) {});
    return result.value;
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async {
        await _auth.signOut();
      },
    );
  }

  Future<void> resendConfirmation({required String email}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async {
        await _auth.resend(
          type: OtpType.signup,
          email: email,
          emailRedirectTo: _androidOnlyCallbackUrl,
        );
      },
    );
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
