import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/session_service.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const LiveSessionScreen({super.key, required this.sessionId});
  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _liveCtrl;
  final _elapsed = ValueNotifier<int>(0);
  late Timer _elapsedTimer;
  Timer? _pollTimer;
  WebViewController? _webCtrl;
  bool _webReady = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _liveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) => _elapsed.value++);
    // Poll every 5s until teacher starts the session (room_url appears).
    // Direct fetch avoids invalidating the StreamProvider (which would cause a loading flash).
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_webCtrl != null || !mounted) { _pollTimer?.cancel(); return; }
      SessionService.getSession(widget.sessionId).then((s) {
        if (!mounted || _webCtrl != null) return;
        final url = s.roomUrl;
        if (url != null) _initWebView(url);
      });
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _liveCtrl.dispose();
    _elapsedTimer.cancel();
    _pollTimer?.cancel();
    _elapsed.dispose();
    super.dispose();
  }

  void _initWebView(String url) {
    if (_webCtrl != null || kIsWeb) return;
    _webCtrl = WebViewController(
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _webReady = true),
      ))
      ..loadRequest(Uri.parse(url));
    setState(() {});
  }

  String _formatTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));

    return sessionAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF10171E),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFF10171E),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              const Text('تعذّر الاتصال', style: TextStyle(color: Colors.white)),
              TextButton(
                onPressed: () => ref.invalidate(sessionProvider(widget.sessionId)),
                child: const Text('إعادة المحاولة', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        ),
      ),
      data: (session) {
        if (session == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF10171E),
            body: Center(child: Text('الجلسة غير موجودة', style: TextStyle(color: Colors.white))),
          );
        }

        // Session ended externally — navigate away
        if (session.state == SessionState.completed ||
            session.state == SessionState.studentNoShow ||
            session.state == SessionState.dispute) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/sessions');
          });
        }

        final roomUrl = session.roomUrl;
        if (roomUrl != null) _initWebView(roomUrl);

        return Scaffold(
          backgroundColor: const Color(0xFF10171E),
          body: Stack(
            children: [
              // Main area: WebView or waiting screen
              roomUrl != null && _webCtrl != null
                  ? Stack(
                      children: [
                        WebViewWidget(controller: _webCtrl!),
                        if (!_webReady)
                          Container(
                            color: const Color(0xFF10171E),
                            child: const Center(
                              child: CircularProgressIndicator(color: AppColors.accent),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: const Color(0xFF161E27),
                      child: ValueListenableBuilder<int>(
                        valueListenable: _elapsed,
                        builder: (_, secs, __) {
                          final canReport = secs >= 900; // 15 min
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 90, height: 90,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                alignment: Alignment.center,
                                child: Text(session.teacherInitial,
                                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                              const SizedBox(height: 16),
                              Text(session.teacherName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(height: 8),
                              Text(
                                canReport
                                    ? 'تجاوزت 15 دقيقة — الأستاذ لم يبدأ'
                                    : 'في انتظار الأستاذ لبدء الجلسة…',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: canReport ? const Color(0xFFFCA5A5) : Colors.white54,
                                ),
                              ),
                              if (canReport) ...[
                                const SizedBox(height: 28),
                                GestureDetector(
                                  onTap: () => _reportNoShow(context, session.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Text('الإبلاغ عن غياب الأستاذ',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text('سيُلغى الحجز وتُسترَد دفعتك',
                                  style: TextStyle(fontSize: 11, color: Colors.white38)),
                              ],
                            ],
                          );
                        },
                      ),
                    ),

              // Top bar (only when not in WebView mode or always overlay)
              if (roomUrl == null)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _liveCtrl,
                            builder: (_, __) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.4 + _liveCtrl.value * 0.3),
                                  blurRadius: 12 + _liveCtrl.value * 8,
                                )],
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.circle, color: Colors.white, size: 8),
                                  SizedBox(width: 5),
                                  Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ValueListenableBuilder<int>(
                            valueListenable: _elapsed,
                            builder: (_, s, __) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(_formatTime(s),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _showLeaveDialog(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.error, borderRadius: BorderRadius.circular(999)),
                              child: const Text('مغادرة',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reportNoShow(BuildContext context, String sessionId) async {
    final router    = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('الإبلاغ عن غياب الأستاذ'),
        content: const Text('سيُسجَّل غياب الأستاذ ويمكنك إعادة الجدولة بنفس الدفعة. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الغياب', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await SessionService.reportTeacherNoShow(sessionId);
      if (mounted) router.go('/sessions');
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _showLeaveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مغادرة الجلسة'),
        content: const Text('هل تريد مغادرة الجلسة؟ يمكنك العودة لاحقاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
          TextButton(
            onPressed: () { Navigator.pop(context); context.go('/sessions'); },
            child: const Text('مغادرة', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
