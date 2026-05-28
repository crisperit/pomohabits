import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

class SupabaseEnvException implements Exception {
  SupabaseEnvException(this.message);
  final String message;

  @override
  String toString() => 'SupabaseEnvException: $message';
}

Future<void> initializeSupabase() async {
  if (supabaseUrl.isEmpty) {
    throw SupabaseEnvException(
      'SUPABASE_URL is empty. Pass it via --dart-define (see SETUP.md section 5).',
    );
  }
  if (supabasePublishableKey.isEmpty) {
    throw SupabaseEnvException(
      'SUPABASE_PUBLISHABLE_KEY is empty. Pass it via --dart-define (see SETUP.md section 5).',
    );
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabasePublishableKey);
}
