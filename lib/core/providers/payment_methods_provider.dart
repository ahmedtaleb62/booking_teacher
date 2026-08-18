import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

class PaymentMethod {
  final String method;
  final String label;
  final String number;
  final String holder;
  final bool active;
  final String? logoUrl;

  const PaymentMethod({
    required this.method,
    required this.label,
    required this.number,
    required this.holder,
    required this.active,
    this.logoUrl,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
    method: j['method'] as String? ?? '',
    label:  j['label']  as String? ?? j['method'] as String? ?? '',
    number: j['number'] as String? ?? '',
    holder: j['holder'] as String? ?? '',
    active: j['is_active'] as bool? ?? j['active'] as bool? ?? true,
    logoUrl: j['logo_url'] as String?,
  );
}

final paymentMethodsProvider = FutureProvider.autoDispose<List<PaymentMethod>>((ref) async {
  final rows = await SupabaseService.client
      .from('payment_methods')
      .select()
      .eq('is_active', true)
      .order('created_at');

  return (rows as List)
      .map((j) => PaymentMethod.fromJson(j as Map<String, dynamic>))
      .where((m) => m.number.isNotEmpty)
      .toList();
});
