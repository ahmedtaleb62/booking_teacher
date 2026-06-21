import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/session_service.dart';

class TeacherLiveSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const TeacherLiveSessionScreen({super.key, required this.sessionId});
  @override
  ConsumerState<TeacherLiveSessionScreen> createState() => _TeacherLiveSessionScreenState();
}

class _TeacherLiveSessionScreenState extends ConsumerState<TeacherLiveSessionScreen> {
  final _elapsed = ValueNotifier<int>(0);
  late Timer _timer;
  WebViewController? _webCtrl;
  bool _webReady = false;
  bool _starting = false;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _elapsed.value++);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer.cancel();
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

  Future<void> _startSession() async {
    setState(() => _starting = true);
    try {
      final url = await SessionService.startSession(widget.sessionId);
      _initWebView(url);
      ref.invalidate(sessionProvider(widget.sessionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء بدء الجلسة')));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _endSession() async {
    setState(() => _ending = true);
    try {
      await SessionService.endSession(widget.sessionId);
      if (mounted) context.go('/teacher/sessions');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء إنهاء الجلسة')));
        setState(() => _ending = false);
      }
    }
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
        body: Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.white))),
      ),
      data: (session) {
        if (session == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF10171E),
            body: Center(child: Text('الجلسة غير موجودة', style: TextStyle(color: Colors.white))),
          );
        }

        final roomUrl = session.roomUrl;
        if (roomUrl != null) _initWebView(roomUrl);

        return Scaffold(
          backgroundColor: const Color(0xFF10171E),
          body: Stack(
            children: [
              // Main: WebView or waiting screen
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
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0, -0.2), radius: 1.2,
                          colors: [Color(0xFF2A3A47), Color(0xFF10171E)],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 110, height: 110,
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text(
                                session.studentName.isNotEmpty ? session.studentName[0] : 'ط',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 44)),
                            ),
                            const SizedBox(height: 16),
                            Text(session.studentName.isNotEmpty ? session.studentName : 'طالب',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(session.subject,
                              style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text('${session.durationMinutes} دقيقة · ${session.amount.toInt()} أوقية',
                              style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            const SizedBox(height: 32),
                            GestureDetector(
                              onTap: _starting ? null : _startSession,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                                decoration: BoxDecoration(
                                  color: _starting ? Colors.white24 : const Color(0xFF1B9E77),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(
                                    color: const Color(0xFF1B9E77).withValues(alpha: 0.5),
                                    blurRadius: 20, offset: const Offset(0, 8),
                                  )],
                                ),
                                child: _starting
                                    ? const SizedBox(width: 24, height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : const Text('بدء الجلسة الآن',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

              // Top bar overlay (always shown)
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE03E3E).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                              const SizedBox(width: 7),
                              ValueListenableBuilder<int>(
                                valueListenable: _elapsed,
                                builder: (_, s, __) => Text('مباشر · ${_formatTime(s)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _ending ? null : () => _showEndDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE03E3E),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: _ending
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('إنهاء الجلسة',
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

  void _showEndDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2330),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إنهاء الجلسة؟',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('هل أنت متأكد من إنهاء الجلسة؟ سيُعلَم الطالب.',
          style: TextStyle(color: Color(0xFF9DB2B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متابعة', style: TextStyle(color: Color(0xFF7BE0C0))),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _endSession(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE03E3E), foregroundColor: Colors.white),
            child: const Text('إنهاء'),
          ),
        ],
      ),
    );
  }
}
