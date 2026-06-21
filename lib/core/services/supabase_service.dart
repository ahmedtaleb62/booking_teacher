import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static String? get userId => currentUser?.id;

  // Values injected at build time via --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  // Fallback to hardcoded values for local dev only — never commit production keys.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tmrrkqqtpbzckaehnprq.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtcnJrcXF0cGJ6Y2thZWhucHJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1OTY4MzgsImV4cCI6MjA4MzE3MjgzOH0.6Fkl7MqT6qsMeIg-73U42NzoCaDozmnp5T1YPTejYyw',
  );

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
  }

  // Auth
  static Future<AuthResponse> signIn(String email, String password) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': 'student'},
    );
  }

  static Future<void> signOut() => client.auth.signOut();

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}
