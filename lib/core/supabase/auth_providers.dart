import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final currentSessionProvider = Provider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final asyncAuthState = ref.watch(authStateChangesProvider);
  return asyncAuthState.maybeWhen(
    data: (authState) => authState.session,
    orElse: () => client.auth.currentSession,
  );
});
