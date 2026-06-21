import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

class PaymentMethod {
  final String method;
  final String label;
  final String number;
  final String holder;
  final bool active;

  const PaymentMethod({
    required this.method,
    required this.label,
    required this.number,
    required this.holder,
    required this.active,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
    method: j['method'] as String,
    label:  j['label']  as String? ?? j['name'] as String? ?? '',
    number: j['number'] as String? ?? '',
    holder: j['holder'] as String? ?? 'منصة حجز استاذ',
    active: j['active'] as bool? ?? true,
  );
}

final paymentMethodsProvider = FutureProvider.autoDispose<List<PaymentMethod>>((ref) async {
  final row = await SupabaseService.client
      .from('system_settings')
      .select('value')
      .eq('key', 'payment_accounts')
      .single();

  final list = row['value'] as List;
  return list
      .map((j) => PaymentMethod.fromJson(j as Map<String, dynamic>))
      .where((m) => m.active && m.number.isNotEmpty)
      .toList();
});
