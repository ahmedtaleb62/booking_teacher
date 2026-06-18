import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

// ── Raw auth state stream ──────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.authStateChanges;
});

// ── Current session (null when logged out) ─────────────────
final currentSessionProvider = Provider<Session?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (s) => s.session,
    loading: () => SupabaseService.client.auth.currentSession,
    error: (_, __) => null,
  );
});

// ── Is user authenticated? ──────────────────────────────────
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});

// ── Current user profile ────────────────────────────────────
final currentProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  final data = await SupabaseService.client
      .from('profiles')
      .select()
      .eq('id', session.user.id)
      .maybeSingle();
  return data;
});

// ── User role ───────────────────────────────────────────────
final userRoleProvider = Provider<String?>((ref) {
  final profile = ref.watch(currentProfileProvider);
  return profile.when(
    data: (p) => p?['role'] as String?,
    loading: () => null,
    error: (_, __) => null,
  );
});
