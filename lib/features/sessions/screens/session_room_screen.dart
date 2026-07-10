import 'dart:async';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/models/session.dart';
import '../../../core/utils/app_errors.dart';
import '../../../core/models/session_message.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/supabase_service.dart';
import 'video_call_screen.dart';

// ─── WhatsApp-like color palette ─────────────────────────────────────────────
const _kChatBg  = Color(0xFFF0EBE3);  // warm light beige chat background
const _kSentBg  = Color(0xFFDCF8C6);  // sent bubble (WhatsApp green)
const _kRecvBg  = Colors.white;
const _kBarBg   = Colors.white;
const _kFieldBg = Color(0xFFF0F2F5);
// ─────────────────────────────────────────────────────────────────────────────

class SessionRoomScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final bool isTeacher;
  final bool readOnly;

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

  // ── Timer ─────────────────────────────────────────────────────────────────
  final _elapsed = ValueNotifier<int>(0);
  Timer? _elapsedTimer;
  int _sessionDurationSeconds = 0;
  bool _warnShown = false;
  DateTime? _scheduledAt;

  // ── Video call ────────────────────────────────────────────────────────────
  String? _myCallUrl;
  String? _acknowledgedCallUrl;
  Timer?  _callTimeoutTimer;

  // ── Input ─────────────────────────────────────────────────────────────────
  final _textCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  // ── Audio recording ───────────────────────────────────────────────────────
  AudioRecorder? _recorder;
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordStart;

  // ── Message editing ───────────────────────────────────────────────────────
  SessionMessage? _editingMsg;

  // ── Audio playback ────────────────────────────────────────────────────────
  final _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  bool _audioPlaying = false;
  Duration _audioPos = Duration.zero;

  // ── Nav guard ─────────────────────────────────────────────────────────────
  bool _exited = false;
  bool _sessionOver = false;
  bool _activationAttempted = false;
  Session? _cachedSession;

  // ── Presence ─────────────────────────────────────────────────────────────
  RealtimeChannel? _presenceChannel;
  bool _otherOnline = false;

  // ── LIVE animation ────────────────────────────────────────────────────────
  late final AnimationController _liveCtrl;

  String get _myId => SupabaseService.userId ?? '';

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _liveCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _loadMessages();
    if (!widget.readOnly) {
      _subscribeMessages();
      _initPresence();
      _startTimer();
    }
    _initAudioPlayer();

    if (!widget.readOnly && !widget.isTeacher) {
      SessionService.markStudentJoined(widget.sessionId).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _liveCtrl.dispose();
    _elapsedTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _elapsed.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder?.dispose();
    _audioPlayer.dispose();
    if (_msgChannel != null) SupabaseService.client.removeChannel(_msgChannel!);
    if (_presenceChannel != null) SupabaseService.client.removeChannel(_presenceChannel!);
    super.dispose();
  }

  // ── Presence ──────────────────────────────────────────────────────────────
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
    final state  = _presenceChannel!.presenceState();
    final online = state.any((s) => s.presences.any((p) {
      final uid = p.payload['user_id'] as String?;
      return uid != null && uid != _myId;
    }));
    setState(() => _otherOnline = online);
  }

  // ── Audio player ──────────────────────────────────────────────────────────
  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen(
        (s) { if (mounted) setState(() => _audioPlaying = s == PlayerState.playing); });
    _audioPlayer.onPositionChanged.listen(
        (p) { if (mounted) setState(() => _audioPos = p); });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _currentlyPlayingId = null;
        _audioPlaying = false;
        _audioPos = Duration.zero;
      });
    });
  }

  // ── Messages ──────────────────────────────────────────────────────────────
  Future<void> _loadMessages() async {
    try {
      final msgs = await MessagingService.getMessages(widget.sessionId);
      if (mounted) {
        setState(() {
          // Merge with any realtime messages that arrived during the fetch
          final ids = {for (final m in msgs) m.id};
          final extra = _messages.where((m) => !ids.contains(m.id)).toList();
          _messages = [...msgs, ...extra]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        _scrollToBottom(animated: false);
      }
    } catch (_) {
      if (mounted) _showError(context.l10n.roomErrLoadMessages);
    }
  }

  void _subscribeMessages() {
    _msgChannel = MessagingService.subscribeToMessages(
      widget.sessionId,
      onInsert: (msg) {
        if (!mounted) return;
        if (_messages.any((m) => m.id == msg.id)) return; // deduplicate
        setState(() {
          _messages = [..._messages, msg]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
        _scrollToBottom();
      },
      onUpdate: (msg) {
        if (!mounted) return;
        setState(() => _messages = _messages.map((m) => m.id == msg.id ? msg : m).toList());
      },
      onDelete: (msgId) {
        if (!mounted) return;
        setState(() => _messages = _messages.where((m) => m.id != msgId).toList());
      },
    );
  }

  void _scrollToBottom({bool animated = true}) {
    // With reverse: true, offset 0.0 is always the visual bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      if (animated) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scrollCtrl.jumpTo(0);
      }
    });
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _tryActivate() {
    if (_activationAttempted || _cachedSession == null) return;
    _activationAttempted = true;
    SessionService.activateSession(widget.sessionId).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('بدأت الجلسة الآن'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 4),
        ));
      }
    }).catchError((_) {});
  }

  void _startTimer() {
    Future<void> seed() async {
      try {
        final s = await SessionService.getSession(widget.sessionId);
        if (!mounted) return;
        _cachedSession = s;
        _scheduledAt = s.scheduledAt;
        _sessionDurationSeconds = s.durationMinutes * 60;
        final elapsed = DateTime.now().difference(s.scheduledAt).inSeconds;
        _elapsed.value = elapsed.clamp(0, 999999);

        if (s.state == SessionState.confirmedBooking ||
            s.state == SessionState.paymentConfirmed) {
          if (elapsed >= 0) {
            // Time already reached — activate immediately
            _tryActivate();
          } else {
            // Entered early — schedule activation when time arrives
            Future.delayed(Duration(seconds: -elapsed), () {
              if (mounted) _tryActivate();
            });
          }
        }

        // If already past end time, handle immediately
        if (_sessionDurationSeconds > 0 && elapsed >= _sessionDurationSeconds) {
          _handleTimeUp();
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_scheduledAt != null) {
          _elapsed.value = DateTime.now().difference(_scheduledAt!).inSeconds.clamp(0, 999999);
        } else {
          _elapsed.value++;
        }
        _checkWarn();
        if (_sessionDurationSeconds > 0 &&
            _elapsed.value >= _sessionDurationSeconds &&
            !_sessionOver) {
          _elapsedTimer?.cancel();
          _handleTimeUp();
        }
      });
    }
    seed();
  }

  void _checkWarn() {
    if (_sessionDurationSeconds <= 0 || _warnShown) return;
    if (_sessionDurationSeconds - _elapsed.value == 300) {
      _warnShown = true;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.roomWarn5Min),
        duration: const Duration(seconds: 6),
        backgroundColor: const Color(0xFFD97706),
      ));
    }
  }

  void _handleTimeUp() {
    if (!mounted || _sessionOver) return;
    _sessionOver = true; // synchronous guard before any async call
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.l10n.roomTimeUp),
      duration: const Duration(seconds: 3),
      backgroundColor: AppColors.error,
    ));
    SessionService.endSession(widget.sessionId).catchError((_) {});
    Future.delayed(const Duration(seconds: 3), () {
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

  String _fmt(int secs) =>
      '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';

  // ── Teacher actions ───────────────────────────────────────────────────────
  void _leaveTeacher() {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.roomLeaveTeacherTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(l.roomLeaveTeacherBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SessionService.recordTeacherLeft(widget.sessionId).catchError((_) {});
              if (mounted) context.go('/teacher/sessions');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text(l.roomLeave),
          ),
        ],
      ),
    );
  }

  void _leave() {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.roomLeaveStudentTitle),
        content: Text(l.roomLeaveStudentBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
          TextButton(
            onPressed: () { Navigator.pop(context); context.go('/sessions'); },
            child: Text(l.roomLeave, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Video call ─────────────────────────────────────────────────────────────
  Future<void> _callVideo(Session session) async {
    final l = context.l10n;
    try {
      final myUrl = await SessionService.initiateVideoCall(widget.sessionId);
      setState(() => _myCallUrl = myUrl);
      _notifyOther('مكالمة فيديو واردة 📹',
          '${_senderName()} يريد بدء مكالمة فيديو', type: 'VIDEO_CALL');

      // Auto-hangup after 60 s if nobody joins
      _callTimeoutTimer = Timer(const Duration(seconds: 60), () {
        VideoCallService.hangUp();
        MessagingService.sendText(
          widget.sessionId, '📵 لم يرد — انتهت المكالمة').catchError((_) {});
      });

      await VideoCallService.join(
        sessionId:    widget.sessionId,
        displayName:  _senderName(),
        languageCode: ref.read(localeProvider).languageCode,
        onParticipantJoined: () {
          _callTimeoutTimer?.cancel();
          _callTimeoutTimer = null;
        },
        onTerminated: () {
          _callTimeoutTimer?.cancel();
          _callTimeoutTimer = null;
          SessionService.clearVideoCall(widget.sessionId).catchError((_) {});
        },
        onError: (e) {
          if (!mounted) return;
          if (e == 'permission_denied') {
            _showPermissionDenied();
            return;
          }
          final msg = e.toLowerCase().contains('network') ||
                      e.toLowerCase().contains('connect') ||
                      e.toLowerCase().contains('ice')
              ? 'الاتصال انقطع — تحقق من الإنترنت'
              : 'انتهت المكالمة بسبب خطأ';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        },
      );
    } catch (_) {
      if (mounted) _showError(l.roomErrStartCall);
    } finally {
      _callTimeoutTimer?.cancel();
      _callTimeoutTimer = null;
      if (mounted) setState(() => _myCallUrl = null);
    }
  }

  void _declineCall(String url) {
    setState(() => _acknowledgedCallUrl = url);
    MessagingService.sendText(widget.sessionId, '📵 رفض المكالمة').catchError((_) {});
  }

  // ── Message actions ───────────────────────────────────────────────────────
  void _showMessageOptions(SessionMessage msg) {
    if (widget.readOnly) return;
    final canEdit = msg.type == 'text';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 8),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
                title: Text(context.l10n.roomEditMessage),
                onTap: () { Navigator.pop(context); _startEdit(msg); },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: Text(context.l10n.roomDeleteMessage,
                  style: const TextStyle(color: AppColors.error)),
              onTap: () { Navigator.pop(context); _confirmDelete(msg); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _startEdit(SessionMessage msg) {
    setState(() => _editingMsg = msg);
    _textCtrl.text = msg.content ?? '';
    _textCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _textCtrl.text.length));
  }

  void _cancelEdit() {
    setState(() => _editingMsg = null);
    _textCtrl.clear();
  }

  void _confirmDelete(SessionMessage msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.l10n.roomDeleteMessage,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(context.l10n.roomDeleteMessageConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel)),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteMessage(msg);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(SessionMessage msg) async {
    try {
      await MessagingService.deleteMessage(msg.id);
      if (mounted) {
        setState(() => _messages = _messages.where((m) => m.id != msg.id).toList());
      }
    } catch (_) {
      if (mounted) _showError(context.l10n.roomErrDeleteMessage);
    }
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending || _sessionOver) return;

    // ── Edit mode ─────────────────────────────────────────────────────────
    if (_editingMsg != null) {
      final editing = _editingMsg!;
      setState(() { _editingMsg = null; _sending = true; });
      _textCtrl.clear();
      try {
        await MessagingService.editMessage(editing.id, text);
        if (mounted) {
          setState(() {
            _messages = _messages.map(
                (m) => m.id == editing.id ? m.copyWith(content: text) : m).toList();
          });
        }
      } catch (_) {
        if (mounted) _showError(context.l10n.roomErrEditMessage);
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }

    // ── Normal send ───────────────────────────────────────────────────────
    final l = context.l10n;
    _textCtrl.clear();
    setState(() => _sending = true);
    try {
      await MessagingService.sendText(widget.sessionId, text);
      _notifyOther(_senderName(), text.length > 60 ? '${text.substring(0, 60)}...' : text);
    } catch (_) {
      if (mounted) { _textCtrl.text = text; _showError(l.roomErrSendText); }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sessionOver) return;
    final l = context.l10n;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (file == null || !mounted) return;
      setState(() => _sending = true);
      await MessagingService.sendImage(
          widget.sessionId, await file.readAsBytes(), file.path.split('.').last.toLowerCase());
      _notifyOther(_senderName(), 'أرسل لك صورة 🖼️');
    } catch (_) {
      if (mounted) _showError(l.roomErrSendImage);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    if (_sessionOver) return;
    final l = context.l10n;
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty || !mounted) return;
      final picked = result.files.first;
      if (picked.bytes == null) return;
      setState(() => _sending = true);
      await MessagingService.sendFile(
        widget.sessionId, picked.bytes!, picked.name,
        picked.extension != null ? 'application/${picked.extension}' : 'application/octet-stream',
      );
      _notifyOther(_senderName(), 'أرسل لك ملفاً 📎: ${picked.name}');
    } catch (_) {
      if (mounted) _showError(l.roomErrSendFile);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startRecording() async {
    if (_sessionOver) return;
    final l = context.l10n;
    try {
      _recorder ??= AudioRecorder();
      if (!await _recorder!.hasPermission()) {
        if (mounted) _showError(l.roomErrMicPermission);
        return;
      }
      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.start(const RecordConfig(), path: _recordingPath!);
      _recordStart = DateTime.now();
      setState(() => _isRecording = true);
      HapticFeedback.lightImpact();
    } catch (_) {
      if (mounted) _showError(l.roomErrStartRecording);
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording || _recorder == null) return;
    try { await _recorder!.stop(); } catch (_) {}
    setState(() { _isRecording = false; _recordingPath = null; _recordStart = null; });
    HapticFeedback.lightImpact();
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _recorder == null) return;
    try {
      await _recorder!.stop();
      final path  = _recordingPath;
      final start = _recordStart;
      setState(() { _isRecording = false; _recordingPath = null; _recordStart = null; });
      if (path == null || start == null) return;
      final dur = DateTime.now().difference(start).inSeconds;
      if (dur < 1) return;
      final bytes = await File(path).readAsBytes();
      setState(() => _sending = true);
      await MessagingService.sendAudio(widget.sessionId, bytes, dur);
      _notifyOther(_senderName(), 'رسالة صوتية 🎤');
    } catch (_) {
      if (mounted) _showError(context.l10n.roomErrSendAudio);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleAudio(String msgId, String url) async {
    if (_currentlyPlayingId == msgId && _audioPlaying) {
      await _audioPlayer.pause();
    } else if (_currentlyPlayingId == msgId && !_audioPlaying) {
      await _audioPlayer.resume();
    } else {
      await _audioPlayer.stop();
      setState(() { _currentlyPlayingId = msgId; _audioPos = Duration.zero; });
      await _audioPlayer.play(UrlSource(url));
    }
  }

  // ── Save / Download ────────────────────────────────────────────────────────
  Future<void> _saveImageToGallery(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      await Gal.putImageBytes(res.bodyBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.roomImageSaved),
              backgroundColor: const Color(0xFF25D366)),
        );
      }
    } catch (_) {
      if (mounted) _showError(context.l10n.roomErrSaveImage);
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.roomDownloadingFile), duration: const Duration(seconds: 2)),
      );
      final res  = await http.get(Uri.parse(url));
      final dir  = await getApplicationDocumentsDirectory();
      final safe = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File('${dir.path}/$safe');
      await file.writeAsBytes(res.bodyBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $safe'),
            backgroundColor: const Color(0xFF25D366),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: context.l10n.roomOpenInBrowser,
              textColor: Colors.white,
              onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) _showError(context.l10n.roomErrDownloadFile);
    }
  }

  // ── Image viewer ──────────────────────────────────────────────────────────
  void _showImageViewer(String url) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _ImageViewerPage(
        url: url,
        onSave: () => _saveImageToGallery(url),
      ),
    ));
  }

  void _showImageOptions(String url) {
    final l = context.l10n;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.black12,
                    borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded, color: AppColors.primary),
              title: Text(l.roomSaveToGallery),
              onTap: () { Navigator.pop(context); _saveImageToGallery(url); },
            ),
            ListTile(
              leading: const Icon(Icons.zoom_in_rounded),
              title: Text(l.roomViewFullSize),
              onTap: () { Navigator.pop(context); _showImageViewer(url); },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser_rounded),
              title: Text(l.roomOpenInBrowser),
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _notifyOther(String title, String body, {String type = 'SESSION_MESSAGE'}) {
    final session = ref.read(sessionProvider(widget.sessionId)).valueOrNull;
    if (session == null) return;
    MessagingService.notifyRecipient(
      recipientId: widget.isTeacher ? session.studentId : session.teacherId,
      title: title, body: body, sessionId: widget.sessionId, type: type,
      extra: {'role': widget.isTeacher ? 'student' : 'teacher'},
    );
  }

  String _senderName() {
    final s = ref.read(sessionProvider(widget.sessionId)).valueOrNull;
    if (s == null) return widget.isTeacher ? 'الأستاذ' : 'الطالب';
    return widget.isTeacher ? s.teacherName : s.studentName;
  }

  String _otherName(Session? s) {
    if (s == null) return widget.isTeacher ? 'الطالب' : 'الأستاذ';
    return widget.isTeacher ? s.studentName : s.teacherName;
  }

  String _otherInitial(Session? s) {
    final name = _otherName(s);
    return name.isNotEmpty ? name[0] : '؟';
  }

  String? _otherAvatarUrl(Session? s) {
    if (s == null) return null;
    return widget.isTeacher ? s.studentAvatarUrl : s.teacherAvatarUrl;
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  void _showPermissionDenied() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('يرجى منح إذن الكاميرا والميكروفون من إعدادات التطبيق'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'الإعدادات',
          textColor: Colors.white,
          onPressed: () => AppSettings.openAppSettings(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    return sessionAsync.when(
      loading: () => const _ChatLoader(),
      error:   (e, _) => _ChatLoader(label: AppErrors.friendly(e, context.l10n)),
      data:    (session) {
        if (session == null) return const _ChatLoader(label: 'الجلسة غير موجودة');

        final incomingCall = session.roomUrl != null
            && session.roomUrl != _acknowledgedCallUrl
            && session.roomUrl != _myCallUrl;

        if (widget.readOnly) {
          return Scaffold(
            backgroundColor: _kChatBg,
            body: Column(children: [
              _buildTopBar(context, session),
              Expanded(child: _buildMessagesList(session)),
              if (!widget.isTeacher) _buildArchiveBar(context, session),
            ]),
          );
        }

        final terminal = {
          SessionState.completed, SessionState.cancelled,
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
          backgroundColor: _kChatBg,
          resizeToAvoidBottomInset: true,
          body: Stack(children: [
            Column(children: [
              _buildTopBar(context, session),
              Expanded(child: _buildMessagesList(session)),
              _buildInputBar(context, session),
            ]),
            if (incomingCall) _buildIncomingCallBanner(session),
          ]),
        );
      },
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, Session session) {
    final l       = context.l10n;
    final other   = _otherName(session);
    final initial = _otherInitial(session);
    final avatarUrl = _otherAvatarUrl(session);

    return Material(
      elevation: 2,
      color: _kBarBg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              // Leave / back
              IconButton(
                icon: Icon(
                  widget.readOnly ? Icons.arrow_back_rounded : Icons.call_end_rounded,
                  color: widget.readOnly ? Colors.black54 : AppColors.error,
                  size: 22,
                ),
                onPressed: widget.readOnly
                    ? () => context.pop()
                    : (widget.isTeacher ? _leaveTeacher : _leave),
              ),

              // Avatar (photo or initial)
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: avatarUrl != null
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(initial,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.primary))
                    : null,
              ),
              const SizedBox(width: 10),

              // Name + status
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(other, style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
                    if (!widget.readOnly)
                      Row(children: [
                        Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: _otherOnline ? const Color(0xFF25D366) : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          _otherOnline ? l.roomOnline : l.roomOffline,
                          style: TextStyle(fontSize: 11,
                              color: _otherOnline ? const Color(0xFF25D366) : Colors.black38),
                        ),
                      ]),
                    if (widget.readOnly)
                      Text(l.roomChatLog,
                          style: const TextStyle(fontSize: 11, color: Colors.black38)),
                  ],
                ),
              ),

              // Subject chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(translateSubject(session.subject, Localizations.localeOf(context)),
                    style: TextStyle(fontSize: 11, color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),

              // Timer
              if (!widget.readOnly)
                ValueListenableBuilder<int>(
                  valueListenable: _elapsed,
                  builder: (_, elapsed, __) {
                    final hasLimit  = _sessionDurationSeconds > 0;
                    final remaining = hasLimit
                        ? (_sessionDurationSeconds - elapsed).clamp(0, _sessionDurationSeconds)
                        : null;
                    final isLow = remaining != null && remaining <= 300;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLow
                            ? AppColors.error.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        remaining != null ? _fmt(remaining) : _fmt(elapsed),
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: isLow ? AppColors.error : Colors.black54),
                      ),
                    );
                  },
                ),

              // LIVE badge
              if (!widget.readOnly && session.isLive) ...[
                const SizedBox(width: 4),
                AnimatedBuilder(
                  animation: _liveCtrl,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3 + _liveCtrl.value * 0.3),
                        blurRadius: 6 + _liveCtrl.value * 6,
                      )],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, color: Colors.white, size: 6),
                      SizedBox(width: 4),
                      Text('LIVE',
                          style: TextStyle(color: Colors.white, fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // ── START BANNER (teacher) ────────────────────────────────────────────────
  // ── MESSAGES LIST ─────────────────────────────────────────────────────────
  Widget _buildMessagesList(Session session) {
    if (_messages.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.black26, size: 20),
            const SizedBox(height: 6),
            Text(
              widget.readOnly
                  ? context.l10n.roomNoMessagesReadOnly
                  : context.l10n.roomNoMessages,
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ]),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg  = _messages[_messages.length - 1 - i];
        final prev = i < _messages.length - 1
            ? _messages[_messages.length - 2 - i]
            : null;
        final isMine     = msg.senderId == _myId;
        final showAvatar = !isMine &&
            (prev == null || prev.senderId != msg.senderId);
        return _buildBubbleRow(msg, isMine, showAvatar, session);
      },
    );
  }

  Widget _buildBubbleRow(SessionMessage msg, bool isMine, bool showAvatar, Session session) {
    final avatarUrl = _otherAvatarUrl(session);
    final bubble = isMine && !widget.readOnly
        ? GestureDetector(
            onLongPress: () => _showMessageOptions(msg),
            child: _buildBubble(msg, isMine),
          )
        : _buildBubble(msg, isMine);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              if (showAvatar)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage: avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(_otherInitial(session),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: AppColors.primary))
                      : null,
                )
              else
                const SizedBox(width: 28),
              const SizedBox(width: 6),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              child: bubble,
            ),
            if (isMine) const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(SessionMessage msg, bool isMine) {
    final time = '${msg.createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
        '${msg.createdAt.toLocal().minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: isMine ? _kSentBg : _kRecvBg,
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(18),
          topRight:    const Radius.circular(18),
          bottomLeft:  Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4  : 18),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: _bubbleContent(msg, time, isMine),
    );
  }

  Widget _bubbleContent(SessionMessage msg, String time, bool isMine) {
    switch (msg.type) {
      // ── Text ──────────────────────────────────────────────────────────────
      case 'text':
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(msg.content ?? '',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.45)),
              const SizedBox(height: 3),
              _timeTick(time, isMine),
            ],
          ),
        );

      // ── Image ─────────────────────────────────────────────────────────────
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.fileUrl != null)
              GestureDetector(
                onTap:      () => _showImageViewer(msg.fileUrl!),
                onLongPress: () => _showImageOptions(msg.fileUrl!),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18), topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4),
                  ),
                  child: Stack(children: [
                    CachedNetworkImage(
                      imageUrl: msg.fileUrl!,
                      width: 220, height: 180, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 220, height: 180, color: Colors.black.withValues(alpha: 0.05),
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 220, height: 180, color: Colors.black.withValues(alpha: 0.05),
                        child: const Icon(Icons.broken_image_rounded, color: Colors.black26, size: 36),
                      ),
                    ),
                    Positioned(
                      bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: _timeTick(time, isMine),
            ),
          ],
        );

      // ── Audio ─────────────────────────────────────────────────────────────
      case 'audio':
        final isThis    = _currentlyPlayingId == msg.id;
        final isPlaying = isThis && _audioPlaying;
        final dur       = msg.durationSec ?? 0;
        final progress  = (isThis && dur > 0)
            ? (_audioPos.inMilliseconds / (dur * 1000)).clamp(0.0, 1.0)
            : 0.0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () { if (msg.fileUrl != null) _toggleAudio(msg.id, msg.fileUrl!); },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isMine ? const Color(0xFF128C7E) : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 110, height: 26,
                    child: CustomPaint(painter: _WaveformPainter(progress: progress.toDouble())),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isThis
                        ? '${_audioPos.inMinutes}:${(_audioPos.inSeconds % 60).toString().padLeft(2, '0')}'
                        : '${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                ]),
              ]),
              const SizedBox(height: 4),
              _timeTick(time, isMine),
            ],
          ),
        );

      // ── File ─────────────────────────────────────────────────────────────
      case 'file':
        final fileName = msg.content ?? 'ملف';
        final ext = fileName.contains('.')
            ? fileName.split('.').last.toUpperCase()
            : 'FILE';
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: isMine ? const Color(0xFF128C7E) : AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    ext.length > 4 ? ext.substring(0, 4) : ext,
                    style: const TextStyle(color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fileName,
                        style: const TextStyle(fontSize: 13, color: Colors.black87,
                            fontWeight: FontWeight.w600),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(context.l10n.roomFileTapHint,
                        style: const TextStyle(fontSize: 10, color: Colors.black38)),
                  ]),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () { if (msg.fileUrl != null) _downloadFile(msg.fileUrl!, fileName); },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.download_rounded, size: 18, color: Colors.black54),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              _timeTick(time, isMine),
            ],
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Text(msg.content ?? '', style: const TextStyle(color: Colors.black87)),
        );
    }
  }

  Widget _timeTick(String time, bool isMine) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(time, style: const TextStyle(fontSize: 10, color: Colors.black38)),
      if (isMine) ...[
        const SizedBox(width: 3),
        const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF53BDEB)),
      ],
    ]);
  }

  // ── INPUT BAR ──────────────────────────────────────────────────────────────
  Widget _buildInputBar(BuildContext context, Session session) {
    final bottom = MediaQuery.of(context).padding.bottom;
    if (_sessionOver) {
      return Material(
        elevation: 4,
        color: _kBarBg,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            alignment: Alignment.center,
            child: Text(
              context.l10n.roomTimeUp,
              style: const TextStyle(
                color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }
    return Material(
      elevation: 4,
      color: _kBarBg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, bottom + 8),
        child: _isRecording
            ? _buildRecordingBar()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit banner
                  if (_editingMsg != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(context.l10n.roomEditMessage,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _cancelEdit,
                          child: const Icon(Icons.close_rounded,
                              size: 16, color: AppColors.primary),
                        ),
                      ]),
                    ),
                  // Attachment row
                  Row(children: [
                    _actionBtn(Icons.image_outlined, context.l10n.roomAttachImage, _pickAndSendImage),
                    _actionBtn(Icons.attach_file_rounded, context.l10n.roomAttachFile, _pickAndSendFile),
                    _actionBtn(Icons.mic_rounded, context.l10n.roomAttachAudio, _startRecording),
                    _actionBtn(
                      Icons.videocam_rounded, context.l10n.roomAttachVideo,
                      () => _callVideo(session),
                    ),
                    const Spacer(),
                  ]),
                  const SizedBox(height: 6),
                  // Text + send row
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _kFieldBg,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _textCtrl,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: context.l10n.roomTypeHint,
                            hintStyle: const TextStyle(color: Colors.black38),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: InputBorder.none,
                          ),
                          textDirection: TextDirection.rtl,
                          maxLines: 5, minLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textCtrl,
                      builder: (_, val, __) {
                        final hasText = val.text.trim().isNotEmpty;
                        final isEditing = _editingMsg != null;
                        return GestureDetector(
                          onTap: hasText ? _sendText : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: hasText ? AppColors.primary : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isEditing ? Icons.check_rounded : Icons.send_rounded,
                              color: hasText ? Colors.white : Colors.black26,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ]),
                ],
              ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback? onTap,
      {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24,
              color: onTap == null
                  ? Colors.black12
                  : (active ? AppColors.primary : Colors.black45)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
              fontSize: 10,
              color: onTap == null ? Colors.black12 : Colors.black38)),
        ]),
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        // Cancel recording
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.black54, size: 15),
              const SizedBox(width: 4),
              Text(context.l10n.commonCancel,
                  style: const TextStyle(color: Colors.black54, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
        const SizedBox(width: 6),
        Text(context.l10n.roomRecording,
            style: const TextStyle(
                color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        // Stop + send
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.red, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.stop_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(context.l10n.roomStopSend,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── ARCHIVE BAR ───────────────────────────────────────────────────────────
  Widget _buildArchiveBar(BuildContext context, Session session) {
    return Material(
      elevation: 4,
      color: _kBarBg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/request-session/${session.teacherId}'),
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text(context.l10n.roomNewBooking),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  // ── INCOMING CALL BANNER ──────────────────────────────────────────────────
  Widget _buildIncomingCallBanner(Session session) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Material(
            borderRadius: BorderRadius.circular(18),
            elevation: 8,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.videocam_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.l10n.roomIncomingCall,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                    Text(widget.isTeacher ? context.l10n.roomCallFromStudent : context.l10n.roomCallFromTeacher,
                        style: const TextStyle(fontSize: 12, color: Colors.black45)),
                  ]),
                ),
                TextButton(
                  onPressed: () => _declineCall(session.roomUrl!),
                  child: Text(context.l10n.roomDeclineCall,
                      style: const TextStyle(color: AppColors.error)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final url = session.roomUrl!;
                    setState(() => _acknowledgedCallUrl = url);
                    if (!mounted) return;
                    await VideoCallService.join(
                      sessionId:    widget.sessionId,
                      displayName:  _senderName(),
                      languageCode: ref.read(localeProvider).languageCode,
                      onTerminated: () =>
                          SessionService.clearVideoCall(widget.sessionId).catchError((_) {}),
                      onError: (e) {
                        if (!mounted) return;
                        if (e == 'permission_denied') {
                          _showPermissionDenied();
                          return;
                        }
                        final msg = e.toLowerCase().contains('network') ||
                                    e.toLowerCase().contains('connect') ||
                                    e.toLowerCase().contains('ice')
                            ? 'الاتصال انقطع — تحقق من الإنترنت'
                            : 'انتهت المكالمة بسبب خطأ';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: Colors.red.shade700,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(context.l10n.roomAcceptCall),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Full-screen image viewer ─────────────────────────────────────────────────
class _ImageViewerPage extends StatelessWidget {
  final String url;
  final VoidCallback onSave;
  const _ImageViewerPage({required this.url, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 6.0,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white54)),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image_rounded, color: Colors.white30, size: 56),
            ),
          ),
        ),
        SafeArea(
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
            ),
            const Spacer(),
            IconButton(
              onPressed: onSave,
              tooltip: 'حفظ في المعرض',
              icon: const Icon(Icons.save_alt_rounded, color: Colors.white, size: 26),
            ),
            IconButton(
              onPressed: () =>
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              tooltip: 'فتح في المتصفح',
              icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 24),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Waveform custom painter ──────────────────────────────────────────────────
class _WaveformPainter extends CustomPainter {
  final double progress;
  _WaveformPainter({required this.progress});

  static const _h = [8.0, 14.0, 10.0, 18.0, 12.0, 20.0, 14.0, 10.0, 16.0, 12.0,
                      8.0, 18.0, 14.0, 10.0, 20.0, 8.0, 16.0, 12.0, 10.0, 14.0];

  @override
  void paint(Canvas canvas, Size size) {
    final count   = _h.length;
    final barW    = (size.width / count) * 0.55;
    final spacing = size.width / count;
    final played  = Paint()..color = const Color(0xFF128C7E)..style = PaintingStyle.fill;
    final rest    = Paint()..color = Colors.black26..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final barH = _h[i] * (size.height / 24);
      final x    = i * spacing + spacing / 2 - barW / 2;
      final y    = (size.height - barH) / 2;
      final rr   = Radius.circular(barW / 2);
      canvas.drawRRect(
          RRect.fromLTRBR(x, y, x + barW, y + barH, rr),
          (i / count) <= progress ? played : rest);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}

// ─── Loading placeholder ──────────────────────────────────────────────────────
class _ChatLoader extends StatelessWidget {
  final String? label;
  const _ChatLoader({this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kChatBg,
      body: Center(
        child: label == null
            ? const CircularProgressIndicator(color: AppColors.primary)
            : Text(label!, style: const TextStyle(color: Colors.black45, fontSize: 14)),
      ),
    );
  }
}
