import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

class CommissionSettings {
  final double sessionPct;
  final double subscriptionPct;

  const CommissionSettings({
    this.sessionPct = 0.15,
    this.subscriptionPct = 0.15,
  });

  int get sessionPctInt => (sessionPct * 100).round();
  int get subscriptionPctInt => (subscriptionPct * 100).round();
  double sessionNet(double amount) => amount * (1.0 - sessionPct);
  double subscriptionNet(double amount) => amount * (1.0 - subscriptionPct);
}

/// Fetches support_phone from system_settings via RPC (bypasses RLS).
final supportPhoneProvider = FutureProvider<String>((ref) async {
  try {
    final rows = await SupabaseService.client.rpc('get_system_settings');
    for (final row in (rows as List<dynamic>)) {
      if ((row['key'] as String?) == 'support_phone') {
        return (row['value'] as String?)?.replaceAll('"', '').trim() ?? '';
      }
    }
    return '';
  } catch (_) {
    return '';
  }
});

/// Fetches session_commission_pct and subscription_commission_pct via RPC (bypasses RLS).
/// Falls back to 15% if the DB is unreachable.
final commissionSettingsProvider = FutureProvider<CommissionSettings>((ref) async {
  try {
    final rows = await SupabaseService.client.rpc('get_system_settings');

    double sessionPct = 0.15;
    double subscriptionPct = 0.15;

    for (final row in (rows as List<dynamic>)) {
      final key = (row['key'] as String?) ?? '';
      final raw = ((row['value'] as String?) ?? '15').replaceAll('"', '').trim();
      final val = double.tryParse(raw) ?? 15.0;
      final pct = val > 1 ? val / 100.0 : val;
      if (key == 'session_commission_pct') sessionPct = pct;
      if (key == 'subscription_commission_pct') subscriptionPct = pct;
    }

    return CommissionSettings(
      sessionPct: sessionPct,
      subscriptionPct: subscriptionPct,
    );
  } catch (_) {
    return const CommissionSettings();
  }
});
