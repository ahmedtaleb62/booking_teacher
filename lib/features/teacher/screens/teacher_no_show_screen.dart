import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/session_service.dart';

class TeacherNoShowScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const TeacherNoShowScreen({super.key, required this.sessionId});
  @override
  ConsumerState<TeacherNoShowScreen> createState() => _TeacherNoShowScreenState();
}

class _TeacherNoShowScreenState extends ConsumerState<TeacherNoShowScreen> {
  final _waitSeconds = ValueNotifier<int>(0);
  late Timer _timer;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    // Seed wait time from actual scheduled time so the display is accurate
    SessionService.getSession(widget.sessionId).then((s) {
      if (!mounted) return;
      final diff = DateTime.now().difference(s.scheduledAt).inSeconds;
      if (diff > 0) _waitSeconds.value = diff;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _waitSeconds.value++);
  }

  @override
  void dispose() {
    _timer.cancel();
    _waitSeconds.dispose();
    super.dispose();
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _recordAbsence() async {
    final l = context.l10n;
    setState(() => _recording = true);
    try {
      await SessionService.reportStudentNoShow(widget.sessionId);

      ref.invalidate(teacherDashboardProvider);
      ref.invalidate(teacherTodaySessionsProvider);
      ref.invalidate(teacherCompletedSessionsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.noShowSuccessMsg),
          backgroundColor: const Color(0xFF1B9E77),
        ),
      );
      if (!mounted) return;
      context.go('/teacher/sessions');
    } catch (e) {
      if (!mounted) return;
      setState(() => _recording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.noShowErrGeneral(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));

    final studentName = sessionAsync.when(
      data: (s) => s?.studentName ?? l.noShowStudentDefault,
      loading: () => l.noShowStudentDefault,
      error: (_, __) => l.noShowStudentDefault,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textPrimary),
                  ),
                ),
                Text(l.noShowTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PulsingClock(),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('STUDENT NO-SHOW',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC77A1A))),
                  ),
                  const SizedBox(height: 16),
                  Text(l.noShowHeadline,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    l.noShowBodyText(studentName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14, color: AppColors.textSecondary, height: 1.7),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l.noShowWaitTime,
                              style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                            ValueListenableBuilder<int>(
                              valueListenable: _waitSeconds,
                              builder: (_, s, __) => Text(_fmt(s),
                                style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        sessionAsync.when(
                          data: (s) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l.noShowYourEarnings,
                                style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                              Text('${s?.amount.toInt() ?? 0} ${l.dashOugiya}',
                                style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1B9E77))),
                            ],
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            color: AppColors.surface,
            padding: EdgeInsets.only(
              left: 22, right: 22, top: 13,
              bottom: MediaQuery.of(context).padding.bottom + 13,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: AppColors.borderStrong),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(l.noShowWaitMore,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _recording ? null : _recordAbsence,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                    ),
                    child: _recording
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l.noShowRecordAndEnd,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingClock extends StatefulWidget {
  @override
  State<_PulsingClock> createState() => _PulsingClockState();
}

class _PulsingClockState extends State<_PulsingClock> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 90, height: 90,
        decoration: const BoxDecoration(color: Color(0xFFFEF3E2), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(color: Color(0xFFF2994A), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
