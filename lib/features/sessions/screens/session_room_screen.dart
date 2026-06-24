import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/models/session.dart';
import '../../../core/models/session_message.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/supabase_service.dart';

class SessionRoomScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final bool isTeacher;
  final bool readOnly; // archive view — no sending, no live features

  const SessionRoomScreen({
    super.key,
    required this.sessionId,
    required this.isTeacher,
    this.readOnly = false,
  });

  @override
  ConsumerState<SessionRoomScreen> createState() => _SessionRoomScreenState();
}

class _SessionRoomScreenState extends ConsumerState<SessionRoomScreen>
    with SingleTickerProviderStateMixin {

  // ── Messages ──────────────────────────────────────────────────────────────
  List<SessionMessage> _messages = [];
  RealtimeChannel? _msgChannel;

  // ── Session timer ─────────────────────────────────────────────────────────
  final _elapsed = ValueNotifier<int>(0);
  Timer? _elapsedTimer;
  int _sessionDurationSeconds = 0; // 0 = unknown/not started
  Timer? _autoEndTimer;
  bool _warnShown = false;

  // ── Video call ────────────────────────────────────────────────────────────
  String? _myCallUrl;       // URL of the call I initiated (suppresses my own banner)
  String? _acknowledgedCallUrl;

  // ── Text input ────────────────────────────────────────────────────────────
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  // ── Audio recording ───────────────────────────────────────────────────────
  AudioRecorder? _recorder;
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordStart;

  // ── Audio playback ────────────────────────────────────────────────────────
  final _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  bool _audioPlaying = false;
  Duration _audioPos = Duration.zero;

  // ── Teacher pre-start ─────────────────────────────────────────────────────
  bool _starting = false;

  // ── Navigation guard ──────────────────────────────────────────────────────
  bool _exited = false;

  // ── Suppress stale call URL on first render ───────────────────────────────
  bool _initialCallUrlCaptured = false;

  // ── Realtime presence ─────────────────────────────────────────────────────
  RealtimeChannel? _presenceChannel;
  bool _otherOnline = false;

  // ── LIVE badge animation ──────────────────────────────────────────────────
  late final AnimationController _liveCtrl;

  String get _myId => SupabaseService.userId ?? '';

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _liveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _loadMessages();
    if (!widget.readOnly) {
      _subscribeMessages();
      _initPresence();
      _startTimer();
    }
    _initAudioPlayer();

    if (!widget.readOnly) {
      // Mark student as joined (prevents STUDENT_NO_SHOW cron)
      if (!widget.isTeacher) {
        SessionService.markStudentJoined(widget.sessionId).catchError((_) {});
      }

      // When session becomes active: re-mark student joined + arm auto-end timer
      ref.listenManual(
        sessionProvider(widget.sessionId),
        (prev, next) {
          final s = next.valueOrNull;
          if (s?.state == SessionState.activeSession &&
              prev?.valueOrNull?.state != SessionState.activeSession) {
            if (!widget.isTeacher) {
              SessionService.markStudentJoined(widget.sessionId).catchError((_) {});
            }
            // Arm the auto-end timer now that startedAt is available
            if (s!.startedAt != null) {
              final diff = DateTime.now().difference(s.startedAt!).inSeconds;
              _elapsed.value = diff > 0 ? diff : 0;
              _sessionDurationSeconds = s.durationMinutes * 60;
              _scheduleAutoEnd();
            }
          }
        },
        fireImmediately: false,
      );
    }
  }

  @override
  void dispose() {
    _liveCtrl.dispose();
    _elapsedTimer?.cancel();
    _autoEndTimer?.cancel();
    _elapsed.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder?.dispose();
    _audioPlayer.dispose();
    if (_msgChannel != null) {
      SupabaseService.client.removeChannel(_msgChannel!);
    }
    if (_presenceChannel != null) {
      SupabaseService.client.removeChannel(_presenceChannel!);
    }
    super.dispose();
  }

  // ── Realtime presence ─────────────────────────────────────────────────────
  void _initPresence() {
    _presenceChannel = SupabaseService.client
        .channel('presence-${widget.sessionId}')
        .onPresenceSync((_) => _syncPresence())
        .onPresenceJoin((_) => _syncPresence())
        .onPresenceLeave((_) => _syncPresence());

    _presenceChannel!.subscribe(([RealtimeSubscribeStatus? status, Object? error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel?.track({'user_id': _myId});
      }
    });
  }

  void _syncPresence() {
    if (!mounted || _presenceChannel == null) return;
    final state = _presenceChannel!.presenceState();
    final online = state.any((s) =>
        s.presences.any((p) {
          final uid = p.payload['user_id'] as String?;
          return uid != null && uid != _myId;
        }));
    setState(() => _otherOnline = online);
  }

  // ── Audio player init ─────────────────────────────────────────────────────
  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _audioPlaying = s == PlayerState.playing);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _audioPos = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _currentlyPlayingId = null;
          _audioPlaying = false;
          _audioPos = Duration.zero;
        });
      }
    });
  }

  // ── Messages ──────────────────────────────────────────────────────────────
  Future<void> _loadMessages() async {
    try {
      final msgs = await MessagingService.getMessages(widget.sessionId);
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) _showError('تعذّر تحميل الرسائل: $e');
    }
  }

  void _subscribeMessages() {
    _msgChannel = MessagingService.subscribeToMessages(
      widget.sessionId,
      (msg) {
        if (!mounted) return;
        setState(() => _messages = [..._messages, msg]);
        _scrollToBottom();
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startTimer() {
    Future<void> seedAndStart() async {
      try {
        final s = await SessionService.getSession(widget.sessionId);
        if (!mounted) return;
        final origin = s.startedAt ?? s.scheduledAt;
        final diff = DateTime.now().difference(origin).inSeconds;
        _elapsed.value = diff > 0 ? diff : 0;
        if (s.state == SessionState.activeSession && s.startedAt != null) {
          _sessionDurationSeconds = s.durationMinutes * 60;
          _scheduleAutoEnd();
        }
      } catch (_) {}
      if (!mounted) return;
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed.value++;
        _checkWarn();
      });
    }
    seedAndStart();
  }

  void _scheduleAutoEnd() {
    _autoEndTimer?.cancel();
    final remaining = _sessionDurationSeconds - _elapsed.value;
    if (remaining <= 0) {
      _handleTimeUp();
      return;
    }
    _autoEndTimer = Timer(Duration(seconds: remaining), _handleTimeUp);
  }

  void _checkWarn() {
    if (_sessionDurationSeconds <= 0 || _warnShown) return;
    final remaining = _sessionDurationSeconds - _elapsed.value;
    if (remaining == 300) {
      _warnShown = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تبقّى 5 دقائق على انتهاء الجلسة'),
          duration: Duration(seconds: 6),
          backgroundColor: Color(0xFFD97706),
        ));
      }
    }
  }

  void _handleTimeUp() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('انتهى وقت الجلسة — ستُغلق تلقائياً قريباً'),
      duration: Duration(seconds: 10),
      backgroundColor: AppColors.error,
    ));
  }

  String _fmt(int secs) =>
      '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';

  // ── Start session (teacher) ────────────────────────────────────────────────
  Future<void> _startSession() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await SessionService.activateSession(widget.sessionId);
      ref.invalidate(sessionProvider(widget.sessionId));
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  // ── Leave (teacher) ───────────────────────────────────────────────────────
  // Teacher cannot end the session manually — it closes automatically when
  // the scheduled time is up (pg_cron). We only record departure time.
  void _leaveTeacher() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2330),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('مغادرة الجلسة؟',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
            'الجلسة ستستمر وتُغلق تلقائياً عند انتهاء وقتها المحدد.',
            style: TextStyle(color: Color(0xFF9DB2B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Color(0xFF7BE0C0))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SessionService.recordTeacherLeft(widget.sessionId).catchError((_) {});
              if (mounted) context.go('/teacher/sessions');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('مغادرة'),
          ),
        ],
      ),
    );
  }

  // ── Leave (student) ───────────────────────────────────────────────────────
  void _leave() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مغادرة الجلسة'),
        content: const Text('يمكنك العودة في أي وقت أثناء بقاء الجلسة نشطة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () { Navigator.pop(context); context.go('/sessions'); },
            child: const Text('مغادرة', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Video call ─────────────────────────────────────────────────────────────
  Future<void> _callVideo(Session session) async {
    try {
      final url = await SessionService.initiateVideoCall(widget.sessionId);
      setState(() => _myCallUrl = url); // suppress my own banner
      _notifyOther(
        'مكالمة فيديو واردة 📹',
        '${_senderName()} يريد بدء مكالمة فيديو — اضغط للرد',
        type: 'VIDEO_CALL',
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) _showError('فشل بدء المكالمة: $e');
    }
  }

  void _declineCall(String callUrl) {
    setState(() => _acknowledgedCallUrl = callUrl);
  }

  // ── Send message helpers ───────────────────────────────────────────────────
  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _textCtrl.clear();
    setState(() => _sending = true);
    try {
      await MessagingService.sendText(widget.sessionId, text);
      _notifyOther(
        _senderName(),
        text.length > 60 ? '${text.substring(0, 60)}...' : text,
      );
    } catch (e) {
      if (mounted) {
        _textCtrl.text = text;
        _showError('فشل إرسال الرسالة: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      setState(() => _sending = true);
      await MessagingService.sendImage(widget.sessionId, bytes, ext);
      _notifyOther(_senderName(), 'أرسل لك صورة 🖼️');
    } catch (e) {
      if (mounted) _showError('فشل إرسال الصورة: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty || !mounted) return;
      final picked = result.files.first;
      if (picked.bytes == null) return;
      setState(() => _sending = true);
      await MessagingService.sendFile(
        widget.sessionId,
        picked.bytes!,
        picked.name,
        picked.extension != null
            ? 'application/${picked.extension}'
            : 'application/octet-stream',
      );
      _notifyOther(_senderName(), 'أرسل لك ملفاً 📎: ${picked.name}');
    } catch (e) {
      if (mounted) _showError('فشل إرسال الملف: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Audio recording ────────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    try {
      _recorder ??= AudioRecorder();
      if (!await _recorder!.hasPermission()) {
        if (mounted) _showError('يرجى السماح للتطبيق بالوصول إلى الميكروفون');
        return;
      }
      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.start(const RecordConfig(), path: _recordingPath!);
      _recordStart = DateTime.now();
      setState(() => _isRecording = true);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) _showError('فشل بدء التسجيل');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _recorder == null) return;
    try {
      await _recorder!.stop();
      final path = _recordingPath;
      final start = _recordStart;
      setState(() { _isRecording = false; _recordingPath = null; _recordStart = null; });
      if (path == null || start == null) return;
      final durationSec = DateTime.now().difference(start).inSeconds;
      if (durationSec < 1) return;
      final bytes = await File(path).readAsBytes();
      setState(() => _sending = true);
      await MessagingService.sendAudio(widget.sessionId, bytes, durationSec);
      _notifyOther(_senderName(), 'رسالة صوتية 🎤');
    } catch (e) {
      if (mounted) _showError('فشل إرسال التسجيل الصوتي: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Audio playback ─────────────────────────────────────────────────────────
  Future<void> _toggleAudio(String msgId, String url) async {
    if (_currentlyPlayingId == msgId && _audioPlaying) {
      await _audioPlayer.pause();
    } else if (_currentlyPlayingId == msgId && !_audioPlaying) {
      await _audioPlayer.resume(); // continue from where we paused
    } else {
      await _audioPlayer.stop();
      setState(() { _currentlyPlayingId = msgId; _audioPos = Duration.zero; });
      await _audioPlayer.play(UrlSource(url));
    }
  }

  // ── Notification helper ────────────────────────────────────────────────────
  // Fire-and-forget: notifies the other party via FCM Edge Function.
  void _notifyOther(String title, String body, {String type = 'SESSION_MESSAGE'}) {
    final session = ref.read(sessionProvider(widget.sessionId)).valueOrNull;
    if (session == null) return;
    final otherId = widget.isTeacher ? session.studentId : session.teacherId;
    MessagingService.notifyRecipient(
      recipientId: otherId,
      title:       title,
      body:        body,
      sessionId:   widget.sessionId,
      type:        type,
      extra:       {'role': widget.isTeacher ? 'student' : 'teacher'},
    );
  }

  String _senderName() {
    final session = ref.read(sessionProvider(widget.sessionId)).valueOrNull;
    if (session == null) return widget.isTeacher ? 'الأستاذ' : 'الطالب';
    return widget.isTeacher ? session.teacherName : session.studentName;
  }

  // ── Error helper ───────────────────────────────────────────────────────────
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    return sessionAsync.when(
      loading: () => const _DarkLoader(),
      error: (e, _) => _DarkLoader(label: '$e'),
      data: (session) {
        if (session == null) return const _DarkLoader(label: 'الجلسة غير موجودة');

        // In read-only (archive) mode skip all live features
        if (widget.readOnly) {
          return Scaffold(
            backgroundColor: const Color(0xFF10171E),
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                _buildTopBar(context, session),
                Expanded(child: _buildMessagesList(session)),
                _buildBottomBar(context, session),
              ],
            ),
          );
        }

        // On first render, mark existing roomUrl as already acknowledged so we
        // never show a banner for a call that happened before we entered the room.
        if (!_initialCallUrlCaptured) {
          _initialCallUrlCaptured = true;
          _acknowledgedCallUrl = session.roomUrl;
        }

        // Compute before any early return so the banner works in pre-start too
        final incomingCall = session.roomUrl != null
            && session.roomUrl != _acknowledgedCallUrl
            && session.roomUrl != _myCallUrl;

        // Auto-exit on terminal state — _exited guard prevents double navigation
        const terminal = {
          SessionState.completed,
          SessionState.teacherNoShow,
          SessionState.studentNoShow,
          SessionState.cancelled,
          SessionState.dispute,
          SessionState.teacherRejected,
        };
        if (terminal.contains(session.state)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _exited) return;
            _exited = true;
            if (widget.isTeacher) {
              ref.invalidate(teacherSessionsProvider);
              context.go('/teacher/sessions');
            } else {
              ref.invalidate(studentSessionsProvider);
              context.go('/sessions');
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFF10171E),
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Column(
                children: [
                  _buildTopBar(context, session),
                  // Teacher start-session prompt when booking is confirmed but not yet active
                  if (widget.isTeacher && session.state == SessionState.confirmedBooking)
                    _buildStartBanner(),
                  Expanded(child: _buildMessagesList(session)),
                  _buildInputBar(context, session),
                ],
              ),
              if (incomingCall) _buildIncomingCallBanner(session),
            ],
          ),
        );
      },
    );
  }

  // ── Teacher start-session banner (confirmedBooking, above messages) ─────────
  Widget _buildStartBanner() {
    return Container(
      color: const Color(0xFF0D131A),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          // Online status dot
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: _otherOnline ? const Color(0xFF10B981) : Colors.white24,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _otherOnline ? 'الطالب متصل' : 'الطالب غير متصل',
            style: TextStyle(
              color: _otherOnline ? const Color(0xFF10B981) : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _starting ? null : _startSession,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF7B61FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _starting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text('بدء الجلسة',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Read-only bottom bar (archive view) ───────────────────────────────────
  Widget _buildBottomBar(BuildContext context, Session session) {
    return Container(
      color: const Color(0xFF0D131A),
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/request-session/${session.teacherId}'),
          icon: const Icon(Icons.calendar_today_rounded, size: 18),
          label: const Text('حجز حصة جديدة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ── Online/offline chip for the other party ───────────────────────────────
  Widget _buildOtherOnlineChip() {
    final label = _otherOnline
        ? (widget.isTeacher ? 'الطالب متصل' : 'الأستاذ متصل')
        : (widget.isTeacher ? 'الطالب غير متصل' : 'الأستاذ غير متصل');
    final dotColor = _otherOnline ? const Color(0xFF10B981) : Colors.white24;
    final textColor = _otherOnline ? const Color(0xFF10B981) : Colors.white38;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, Session session) {
    // Archive mode: simple header with back button
    if (widget.readOnly) {
      return SafeArea(
        bottom: false,
        child: Container(
          color: const Color(0xFF0D131A),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('سجل المحادثة',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(session.subject,
                    style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Container(
        color: const Color(0xFF0D131A),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (session.isLive)
              AnimatedBuilder(
                animation: _liveCtrl,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3 + _liveCtrl.value * 0.3),
                      blurRadius: 8 + _liveCtrl.value * 8,
                    )],
                  ),
                  child: const Row(children: [
                    Icon(Icons.circle, color: Colors.white, size: 7),
                    SizedBox(width: 5),
                    Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ]),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('في الانتظار',
                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: _elapsed,
              builder: (_, elapsed, __) {
                final hasLimit = _sessionDurationSeconds > 0;
                final remaining = hasLimit
                    ? (_sessionDurationSeconds - elapsed).clamp(0, _sessionDurationSeconds)
                    : null;
                final isLow = remaining != null && remaining <= 300;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isLow
                        ? AppColors.error.withValues(alpha: 0.2)
                        : Colors.black38,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    remaining != null ? _fmt(remaining) : _fmt(elapsed),
                    style: TextStyle(
                      color: isLow ? AppColors.error : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            _buildOtherOnlineChip(),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(session.subject,
                  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: widget.isTeacher ? _leaveTeacher : _leave,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'مغادرة',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Messages list ──────────────────────────────────────────────────────────
  Widget _buildMessagesList(Session session) {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white12, size: 52),
            const SizedBox(height: 12),
            Text(
              widget.readOnly ? 'لا توجد رسائل في هذه الجلسة' : 'ابدأ المحادثة',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(SessionMessage msg) {
    final isMine = msg.senderId == _myId;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF7B61FF) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: _bubbleContent(msg),
      ),
    );
  }

  Widget _bubbleContent(SessionMessage msg) {
    final time = '${msg.createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
        '${msg.createdAt.toLocal().minute.toString().padLeft(2, '0')}';
    switch (msg.type) {
      case 'text':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(msg.content ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45)),
            const SizedBox(height: 2),
            Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        );
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.fileUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  msg.fileUrl!,
                  width: 210,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const SizedBox(
                          width: 210, height: 130,
                          child: Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
                        ),
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 210, height: 80,
                    child: Center(child: Icon(Icons.broken_image_rounded, color: Colors.white30)),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        );
      case 'audio':
        final isThis = _currentlyPlayingId == msg.id;
        final isPlaying = isThis && _audioPlaying;
        final dur = msg.durationSec ?? 0;
        final progress = (isThis && dur > 0)
            ? (_audioPos.inMilliseconds / (dur * 1000)).clamp(0.0, 1.0)
            : 0.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                if (msg.fileUrl != null) _toggleAudio(msg.id, msg.fileUrl!);
              },
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        );
      case 'file':
        return GestureDetector(
          onTap: () async {
            if (msg.fileUrl == null) return;
            final uri = Uri.parse(msg.fileUrl!);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_rounded, color: Colors.white70, size: 26),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.content ?? 'ملف',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const Text('اضغط للفتح',
                        style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        return Text(msg.content ?? '', style: const TextStyle(color: Colors.white));
    }
  }

  // ── Input bar ──────────────────────────────────────────────────────────────
  Widget _buildInputBar(BuildContext context, Session session) {
    final bottom = MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom;
    return Container(
      color: const Color(0xFF0D131A),
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottom + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Action toolbar ────────────────────────────────
          if (_isRecording)
            _buildRecordingIndicator()
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionBtn(
                  icon: Icons.videocam_rounded,
                  label: 'فيديو',
                  color: session.isLive ? const Color(0xFF7B61FF) : Colors.white12,
                  iconColor: session.isLive ? Colors.white : Colors.white24,
                  onTap: session.isLive ? () => _callVideo(session) : null,
                ),
                _buildActionBtn(
                  icon: Icons.mic_rounded,
                  label: 'صوتي',
                  color: const Color(0xFF1E293B),
                  iconColor: Colors.white,
                  onTap: _startRecording,
                ),
                _buildActionBtn(
                  icon: Icons.attach_file_rounded,
                  label: 'ملف',
                  color: const Color(0xFF1E293B),
                  iconColor: Colors.white,
                  onTap: _pickAndSendFile,
                ),
                _buildActionBtn(
                  icon: Icons.image_outlined,
                  label: 'صورة',
                  color: const Color(0xFF1E293B),
                  iconColor: Colors.white,
                  onTap: _pickAndSendImage,
                ),
              ],
            ),
          const SizedBox(height: 8),
          // ── Text input row ────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالة...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textDirection: TextDirection.rtl,
                  maxLines: 5,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _textCtrl,
                builder: (_, val, __) {
                  final hasText = val.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: hasText ? _sendText : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: hasText ? const Color(0xFF7B61FF) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(Icons.send_rounded,
                          color: hasText ? Colors.white : Colors.white24, size: 20),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                color: onTap != null ? Colors.white54 : Colors.white24,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
          const SizedBox(width: 8),
          const Text('جاري التسجيل...',
              style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('إيقاف وإرسال',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Incoming call banner ───────────────────────────────────────────────────
  Widget _buildIncomingCallBanner(Session session) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF7B61FF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B61FF).withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B61FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Color(0xFF7B61FF), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مكالمة فيديو واردة',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        widget.isTeacher ? 'من الطالب' : 'من الأستاذ',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _declineCall(session.roomUrl!),
                  child: const Text('رفض', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () async {
                    final url = session.roomUrl!;
                    setState(() => _acknowledgedCallUrl = url);
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B61FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('قبول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

// ── Shared helper widgets ──────────────────────────────────────────────────────

class _DarkLoader extends StatelessWidget {
  final String? label;
  const _DarkLoader({this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10171E),
      body: Center(
        child: label == null
            ? const CircularProgressIndicator(color: Color(0xFF7B61FF))
            : Text(label!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
      ),
    );
  }
}
