import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';

// ── Model ─────────────────────────────────────────────────────────

enum _ItemType { session, subscription }

class _PayItem {
  final String id;
  final _ItemType type;
  final String title;
  final String subtitle;
  final double amount;
  final String status;
  final String? rejectReason;
  final String? reference;
  final DateTime date;
  final String? navPath;

  const _PayItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    this.rejectReason,
    this.reference,
    required this.date,
    this.navPath,
  });

  // Status display helpers
  String get statusLabel {
    if (type == _ItemType.session) {
      switch (status) {
        case 'submitted': return 'قيد المراجعة';
        case 'confirmed': return 'تم القبول';
        case 'rejected':  return 'مرفوض';
        default:          return 'قيد الانتظار';
      }
    } else {
      switch (status) {
        case 'pending':  return 'قيد المراجعة';
        case 'active':   return 'مقبول — نشط';
        case 'rejected': return 'مرفوض';
        case 'expired':  return 'منتهي';
        default:         return status;
      }
    }
  }

  Color get statusColor {
    switch (status) {
      case 'submitted':
      case 'pending':   return const Color(0xFF7B61FF);
      case 'confirmed':
      case 'active':    return AppColors.statusConfirmed;
      case 'rejected':  return AppColors.error;
      case 'expired':   return AppColors.textHint;
      default:          return AppColors.textHint;
    }
  }

  Color get statusBg {
    switch (status) {
      case 'submitted':
      case 'pending':   return const Color(0xFFF0EDFF);
      case 'confirmed':
      case 'active':    return AppColors.statusConfirmedBg;
      case 'rejected':  return AppColors.statusRejectedBg;
      case 'expired':   return AppColors.surfaceAlt;
      default:          return AppColors.surfaceAlt;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────

final _paymentHistoryProvider =
    FutureProvider.autoDispose<List<_PayItem>>((ref) async {
  ref.watch(currentSessionProvider);
  final uid = SupabaseService.userId;
  if (uid == null) return [];

  final results = await Future.wait([
    // Session payments — fetch session fields without nested teacher join
    SupabaseService.client
        .from('payments')
        .select('*, session:session_id(id, subject, teacher_id, scheduled_at)')
        .eq('student_id', uid)
        .order('created_at', ascending: false),
    // Subscription payments
    SupabaseService.client
        .from('subscriptions')
        .select('*, course:course_id(id, title, subject), package:package_id(id, title, subjects)')
        .eq('student_id', uid)
        .order('created_at', ascending: false),
  ]);

  // Resolve teacher names for session payments in a separate query
  final paymentsList = results[0] as List;
  final teacherIds = paymentsList
      .map((p) => ((p as Map)['session'] as Map?)?['teacher_id'])
      .whereType<String>()
      .toSet()
      .toList();

  final Map<String, String> teacherNames = {};
  if (teacherIds.isNotEmpty) {
    final profiles = await SupabaseService.client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', teacherIds);
    for (final p in profiles as List) {
      final m = p as Map;
      teacherNames[m['id'] as String] = m['full_name'] as String? ?? '—';
    }
  }

  final items = <_PayItem>[];

  // Session payments
  for (final p in paymentsList) {
    final m = Map<String, dynamic>.from(p as Map);
    final session = m['session'] as Map<String, dynamic>?;
    final teacherId = session?['teacher_id'] as String?;
    final sessionId = session?['id'] as String?;

    items.add(_PayItem(
      id: m['id'] as String,
      type: _ItemType.session,
      title: (teacherId != null ? teacherNames[teacherId] : null) ?? 'أستاذ',
      subtitle: session?['subject'] as String? ?? '',
      amount: (m['amount'] as num).toDouble(),
      status: m['status'] as String? ?? 'pending',
      rejectReason: m['reject_reason'] as String?,
      reference: m['reference'] as String?,
      date: DateTime.parse(m['created_at'] as String),
      navPath: sessionId != null ? '/session/$sessionId' : null,
    ));
  }

  // Subscription payments
  for (final s in results[1] as List) {
    final m = Map<String, dynamic>.from(s as Map);
    final course = m['course'] as Map<String, dynamic>?;
    final package = m['package'] as Map<String, dynamic>?;
    final subId = m['id'] as String;
    final status = m['status'] as String? ?? 'pending';
    final courseId = m['course_id'] as String?;
    final packageId = m['package_id'] as String?;

    String? nav;
    if (status == 'pending') {
      nav = '/subscription-pending/$subId';
    } else if (status == 'active' && courseId != null) {
      nav = '/course/$courseId';
    } else if (status == 'active' && packageId != null) {
      nav = '/package/$packageId';
    } else if (courseId != null) {
      nav = '/course/$courseId';
    } else if (packageId != null) {
      nav = '/package/$packageId';
    }

    items.add(_PayItem(
      id: subId,
      type: _ItemType.subscription,
      title: course?['title'] as String? ?? package?['title'] as String? ?? '—',
      subtitle: course?['subject'] as String? ??
          package?['subjects'] as String? ??
          'اشتراك',
      amount: (m['amount'] as num).toDouble(),
      status: status,
      rejectReason: m['reject_reason'] as String?,
      date: DateTime.parse(m['created_at'] as String),
      navPath: nav,
    ));
  }

  items.sort((a, b) => b.date.compareTo(a.date));
  return items;
});

// ── Screen ────────────────────────────────────────────────────────

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  int _filterIndex = 0; // 0=all, 1=session, 2=subscription

  List<_PayItem> _applyFilter(List<_PayItem> all) {
    if (_filterIndex == 1) return all.where((i) => i.type == _ItemType.session).toList();
    if (_filterIndex == 2) return all.where((i) => i.type == _ItemType.subscription).toList();
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final histAsync = ref.watch(_paymentHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_forward_rounded,
              color: AppColors.textPrimary),
        ),
        title: const Text('سجل المدفوعات',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: histAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _buildError(e),
        data: (all) {
          final items = _applyFilter(all);
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.refresh(_paymentHistoryProvider.future),
            child: CustomScrollView(
              slivers: [
                // Summary + filters
                SliverToBoxAdapter(
                  child: _buildHeader(all, items),
                ),
                // List
                if (items.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmpty(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildCard(context, items[i]),
                        childCount: items.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(List<_PayItem> all, List<_PayItem> filtered) {
    // Stats
    final totalConfirmed = all
        .where((i) =>
            i.status == 'confirmed' ||
            i.status == 'active' ||
            i.status == 'expired')
        .fold(0.0, (s, i) => s + i.amount);
    final pendingCount = all
        .where((i) => i.status == 'submitted' || i.status == 'pending')
        .length;
    final rejectedCount = all.where((i) => i.status == 'rejected').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B6B7A), Color(0xFF0E4550)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF1B6B7A).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إجمالي المدفوع',
                    style: TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 4),
                Text(
                  '${totalConfirmed.toStringAsFixed(0)} أوقية',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatChip(
                      label: 'إجمالي المعاملات',
                      value: '${all.length}',
                      icon: Icons.receipt_long_rounded,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'قيد المراجعة',
                      value: '$pendingCount',
                      icon: Icons.hourglass_top_rounded,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'مرفوض',
                      value: '$rejectedCount',
                      icon: Icons.cancel_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                    label: 'الكل',
                    count: all.length,
                    selected: _filterIndex == 0,
                    onTap: () => setState(() => _filterIndex = 0)),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'الجلسات',
                    count: all.where((i) => i.type == _ItemType.session).length,
                    selected: _filterIndex == 1,
                    onTap: () => setState(() => _filterIndex = 1)),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'الاشتراكات',
                    count: all.where((i) => i.type == _ItemType.subscription).length,
                    selected: _filterIndex == 2,
                    onTap: () => setState(() => _filterIndex = 2)),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, _PayItem item) {
    final isSession = item.type == _ItemType.session;

    return GestureDetector(
      onTap: item.navPath != null ? () => context.push(item.navPath!) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.status == 'rejected'
                ? AppColors.error.withValues(alpha: 0.25)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type icon
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: isSession
                              ? AppColors.statusApprovedBg
                              : const Color(0xFFF0EDFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          isSession
                              ? Icons.school_rounded
                              : Icons.subscriptions_rounded,
                          color: isSession
                              ? AppColors.statusApproved
                              : const Color(0xFF7B61FF),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSession
                                        ? AppColors.statusApprovedBg
                                        : const Color(0xFFF0EDFF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isSession ? 'جلسة' : 'اشتراك',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isSession
                                            ? AppColors.statusApproved
                                            : const Color(0xFF7B61FF)),
                                  ),
                                ),
                                if (item.subtitle.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(item.subtitle,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textHint),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.amount.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary),
                          ),
                          const Text('أوقية',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textHint)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Status + Date row
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.statusBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                  color: item.statusColor,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(item.statusLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: item.statusColor)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Date
                      Text(_formatDate(item.date),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),

                  // Reference (session payments only)
                  if (item.reference != null && item.reference!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.tag_rounded,
                            size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(item.reference!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textHint,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ],

                  // Reject reason
                  if (item.status == 'rejected' &&
                      item.rejectReason != null &&
                      item.rejectReason!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.statusRejectedBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: AppColors.error),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(item.rejectReason!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Tap hint for navigable items
            if (item.navPath != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isSession ? 'عرض تفاصيل الجلسة' : 'عرض الدورة',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_left_rounded,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.receipt_long_rounded,
                size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('لا توجد مدفوعات بعد',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            _filterIndex == 0
                ? 'ستظهر هنا جميع مدفوعاتك للجلسات والاشتراكات'
                : _filterIndex == 1
                    ? 'لا توجد مدفوعات جلسات'
                    : 'لا توجد مدفوعات اشتراكات',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text('تعذّر تحميل سجل المدفوعات',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(_paymentHistoryProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      '',
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

// ── Helper widgets ─────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.count,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
