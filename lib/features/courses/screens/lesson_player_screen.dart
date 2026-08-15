import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/services/course_service.dart';
import '../../../core/services/screen_secure_service.dart';

class LessonPlayerScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final String? courseId;
  final String? title;
  final String? videoUrl;
  final String? subscriptionId;
  final String lessonType;
  final List<Map<String, dynamic>>? quizData;

  const LessonPlayerScreen({
    super.key,
    required this.lessonId,
    this.courseId,
    this.title,
    this.videoUrl,
    this.subscriptionId,
    this.lessonType = 'video',
    this.quizData,
  });

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  // Video/file state
  WebViewController? _webCtrl;
  bool _webReady = false;
  // Native video player state (direct video files — not YouTube/Vimeo embeds)
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _videoError = false;
  // Quiz state
  final Map<int, int> _answers = {};
  bool _quizSubmitted = false;
  // Common state
  bool _marking = false;
  bool _marked = false;

  bool get _isQuiz =>
      widget.lessonType == 'exercise' &&
      widget.quizData != null &&
      widget.quizData!.isNotEmpty;

  bool get _hasSubscription =>
      widget.subscriptionId != null && widget.subscriptionId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    ScreenSecureService.enable();
    if (!_isQuiz) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final url = widget.videoUrl;
      if (url != null) {
        if (widget.lessonType == 'video' && !_isEmbedUrl(url)) {
          // Direct video file (e.g. uploaded to storage) — use a native
          // player so playback streams properly instead of a WebView
          // navigating straight to the file, which is slow/unreliable.
          _initNativePlayer(url);
        } else {
          _initWebView(_resolveUrl(url));
        }
      }
    }
  }

  @override
  void dispose() {
    ScreenSecureService.disable();
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    if (!_isQuiz) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Widget _backButtonOverlay() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isEmbedUrl(String url) =>
      url.contains('youtube.com') || url.contains('youtu.be') || url.contains('vimeo.com');

  String _resolveUrl(String url) {
    final isFile = widget.lessonType == 'file' || widget.lessonType == 'summary';
    if (isFile && !_isEmbedUrl(url)) {
      return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true';
    }
    return _toEmbedUrl(url) ?? url;
  }

  // YouTube/Vimeo watch-page URLs load the full site (with its own download/
  // share/home UI) inside the WebView. Converting to the minimal embed
  // player removes that chrome entirely instead of trying to hide it.
  String? _toEmbedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
      if (uri.path.contains('/embed/')) return url;
      final videoId = uri.host.contains('youtu.be')
          ? (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null)
          : uri.queryParameters['v'];
      if (videoId == null || videoId.isEmpty) return null;
      return 'https://www.youtube.com/embed/$videoId?playsinline=1&modestbranding=1&rel=0';
    }

    if (uri.host.contains('vimeo.com')) {
      if (uri.host.contains('player.vimeo.com')) return url;
      final videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
      if (videoId == null || videoId.isEmpty) return null;
      return 'https://player.vimeo.com/video/$videoId';
    }

    return null;
  }

  Future<void> _initNativePlayer(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.accent,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
        placeholder: const ColoredBox(color: Colors.black),
        errorBuilder: (context, errorMessage) => Center(
          child: Text(context.l10n.lessonVideoLoadError,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
      );
      setState(() {
        _videoCtrl = controller;
        _chewieCtrl = chewie;
      });
    } catch (_) {
      controller.dispose();
      if (mounted) setState(() => _videoError = true);
    }
  }

  void _initWebView(String url) {
    _webCtrl = WebViewController(
      onPermissionRequest: (req) => req.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _injectProtection();
          setState(() => _webReady = true);
        },
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          // Block blob: URLs (browser-initiated file downloads)
          if (uri.scheme == 'blob') return NavigationDecision.prevent;
          // Block direct file download URLs
          final path = uri.path.toLowerCase();
          const blocked = ['.mp4', '.webm', '.mkv', '.pdf', '.doc',
            '.docx', '.ppt', '.pptx', '.xls', '.xlsx', '.zip', '.rar', '.7z'];
          final isDirect = blocked.any((e) => path.endsWith(e));
          final isTrusted = uri.host.contains('docs.google.com') ||
              uri.host.contains('youtube.com') ||
              uri.host.contains('youtu.be') ||
              uri.host.contains('googleapis.com') ||
              uri.host.contains('supabase.co');
          if (isDirect && !isTrusted) return NavigationDecision.prevent;
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(url));
  }

  void _injectProtection() {
    _webCtrl?.runJavaScript('''
      document.body.style.userSelect = "none";
      document.body.style.webkitUserSelect = "none";
      document.addEventListener("contextmenu", function(e){ e.preventDefault(); }, true);
      document.addEventListener("selectstart",  function(e){ e.preventDefault(); }, true);
      setTimeout(function(){
        document.querySelectorAll(
          '[aria-label="Download"],[data-tooltip="Download"],[aria-label="Print"],'
          +'.ndfHFb-c4YZDc-Wrql6b,.ndfHFb-c4YZDc-to915-LgbsSe'
        ).forEach(function(b){ b.style.display="none"; });
        document.querySelectorAll('a[href*="export=download"],a[download]').forEach(function(a){
          a.addEventListener("click", function(e){ e.preventDefault(); e.stopPropagation(); }, true);
        });
      }, 1500);
    ''');
  }

  Future<void> _markCompleted() async {
    if (_marking || _marked || !_hasSubscription) return;
    setState(() => _marking = true);

    // Best-effort: mark lesson completed — failure doesn't block the rating prompt
    try {
      await CourseService.markLessonCompleted(
        lessonId: widget.lessonId,
        subscriptionId: widget.subscriptionId!,
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() { _marking = false; _marked = true; });

    if (widget.courseId == null) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    bool alreadyRated = false;
    try {
      alreadyRated = await CourseService.hasRatedInCurrentSubscription(
        courseId:       widget.courseId!,
        subscriptionId: widget.subscriptionId,
      );
    } catch (_) {
      // If the check fails, show the rating dialog anyway
    }
    if (mounted && !alreadyRated) _showRatingDialog();
  }

  void _showRatingDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RatingSheet(courseId: widget.courseId!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isQuiz ? _buildQuizScreen() : _buildVideoScreen();
  }

  // ── Quiz screen ──────────────────────────────────────────────────
  Widget _buildQuizScreen() {
    final l = context.l10n;
    final questions = widget.quizData!;
    int correct = 0;
    if (_quizSubmitted) {
      for (int i = 0; i < questions.length; i++) {
        if (_answers[i] == (questions[i]['correct'] as int? ?? 0)) correct++;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1621),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title ?? l.lessonQuizFallback,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_quizSubmitted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B9E77).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$correct/${questions.length}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: Color(0xFF7BE0C0)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Questions list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: questions.length + (_quizSubmitted ? 1 : 0),
                itemBuilder: (_, i) {
                  if (_quizSubmitted && i == questions.length) {
                    return _buildScoreCard(correct, questions.length);
                  }
                  final q = questions[i];
                  final qText = q['text'] as String? ?? '';
                  final answers = (q['answers'] as List?)
                          ?.map((a) => a.toString())
                          .toList() ??
                      [];
                  final correctIdx = q['correct'] as int? ?? 0;
                  return _buildQuestionCard(i, qText, answers, correctIdx, _answers[i]);
                },
              ),
            ),

            // Bottom action
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: _quizSubmitted
                    ? ElevatedButton(
                        onPressed: _marked ? null : _markCompleted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _marked ? const Color(0xFF16A34A) : AppColors.accent,
                          foregroundColor:
                              _marked ? Colors.white : AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _marking
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primaryDark))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _marked
                                        ? Icons.check_circle_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _marked ? l.lessonDone : l.lessonQuizDoneLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ],
                              ),
                      )
                    : ElevatedButton(
                        onPressed: _answers.length < questions.length
                            ? null
                            : () => setState(() => _quizSubmitted = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          _answers.length < questions.length
                              ? l.lessonAnswerAll(_answers.length, questions.length)
                              : l.lessonSubmitAnswers,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
      int qi, String text, List<String> answers, int correctIdx, int? selected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26, height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${qi + 1}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.accent)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: Colors.white, height: 1.4)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ...answers.asMap().entries.map((entry) {
            final ai = entry.key;
            final aText = entry.value;
            Color? bg;
            Color borderCol = Colors.transparent;
            Color textCol = Colors.white70;
            IconData? trailingIcon;
            Color trailingColor = Colors.transparent;

            if (_quizSubmitted) {
              if (ai == correctIdx) {
                bg = const Color(0xFF1B9E77).withValues(alpha: 0.15);
                borderCol = const Color(0xFF1B9E77);
                textCol = const Color(0xFF7BE0C0);
                trailingIcon = Icons.check_circle_rounded;
                trailingColor = const Color(0xFF1B9E77);
              } else if (ai == selected && ai != correctIdx) {
                bg = const Color(0xFFC0392B).withValues(alpha: 0.15);
                borderCol = const Color(0xFFC0392B);
                textCol = const Color(0xFFFF8A8A);
                trailingIcon = Icons.cancel_rounded;
                trailingColor = const Color(0xFFC0392B);
              }
            } else if (ai == selected) {
              bg = AppColors.primary.withValues(alpha: 0.15);
              borderCol = AppColors.primary;
              textCol = AppColors.accent;
            }

            return GestureDetector(
              onTap: _quizSubmitted ? null : () => setState(() => _answers[qi] = ai),
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: borderCol == Colors.transparent
                        ? Colors.transparent
                        : borderCol.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (!_quizSubmitted && ai == selected)
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: _quizSubmitted && ai == correctIdx
                              ? const Color(0xFF1B9E77)
                              : _quizSubmitted && ai == selected
                                  ? const Color(0xFFC0392B)
                                  : ai == selected
                                      ? AppColors.primary
                                      : Colors.white30,
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(aText,
                          style: TextStyle(fontSize: 13, color: textCol, height: 1.3)),
                    ),
                    if (trailingIcon != null)
                      Icon(trailingIcon, size: 16, color: trailingColor),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildScoreCard(int correct, int total) {
    final l = context.l10n;
    final pct = total > 0 ? (correct / total * 100).round() : 0;
    final passed = pct >= 60;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (passed ? const Color(0xFF1B9E77) : const Color(0xFFC0392B))
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (passed ? const Color(0xFF1B9E77) : const Color(0xFFC0392B))
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(children: [
        Icon(
          passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
          color: passed ? const Color(0xFFF59E0B) : const Color(0xFFC0392B),
          size: 36,
        ),
        const SizedBox(height: 10),
        Text(
          passed ? l.lessonQuizPassed : l.lessonQuizFailed,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: passed ? const Color(0xFF7BE0C0) : const Color(0xFFFF8A8A)),
        ),
        const SizedBox(height: 6),
        Text(
          l.lessonQuizScore(correct, total, pct),
          style: const TextStyle(fontSize: 13, color: Colors.white54),
        ),
        if (!passed) ...[
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => setState(() { _answers.clear(); _quizSubmitted = false; }),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              foregroundColor: Colors.white70,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l.commonRetry),
          ),
        ],
      ]),
    );
  }

  // ── Video / File screen ──────────────────────────────────────────
  Widget _buildVideoScreen() {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            flex: widget.videoUrl != null ? 6 : 3,
            child: _chewieCtrl != null
                ? Stack(
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: Center(child: Chewie(controller: _chewieCtrl!)),
                      ),
                      _backButtonOverlay(),
                    ],
                  )
                : widget.videoUrl != null && _webCtrl != null
                ? Stack(
                    children: [
                      WebViewWidget(controller: _webCtrl!),
                      if (!_webReady)
                        const ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.accent),
                          ),
                        ),
                      _backButtonOverlay(),
                    ],
                  )
                : widget.videoUrl != null && widget.lessonType == 'video'
                ? Stack(
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: _videoError
                              ? Text(l.lessonVideoLoadError,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white54, fontSize: 13))
                              : const CircularProgressIndicator(color: AppColors.accent),
                        ),
                      ),
                      _backButtonOverlay(),
                    ],
                  )
                : SafeArea(
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off_outlined,
                                  color: Colors.white38, size: 64),
                              const SizedBox(height: 16),
                              Text(l.lessonNoVideo,
                                  style: const TextStyle(color: Colors.white54, fontSize: 14)),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 12, right: 16,
                          child: GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Info panel
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF0F1621),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.title != null)
                    Text(widget.title!,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    _hasSubscription ? l.lessonVideoHint : l.lessonFreePreview,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white54, height: 1.5),
                  ),
                  const Spacer(),
                  if (_hasSubscription)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _marked ? null : _markCompleted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _marked ? const Color(0xFF16A34A) : AppColors.accent,
                          foregroundColor:
                              _marked ? Colors.white : AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _marking
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primaryDark),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _marked
                                        ? Icons.check_circle_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _marked ? l.lessonDone : l.lessonVideoDoneLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ],
                              ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        l.lessonSubscribeToAccess,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (widget.courseId != null)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => context.pop(),
                        child: Text(l.lessonBackToList,
                            style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rating bottom sheet ───────────────────────────────────────────

class _RatingSheet extends StatefulWidget {
  final String courseId;
  const _RatingSheet({required this.courseId});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _stars = 0;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(l.lessonRatingTitle,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(l.lessonRatingSubtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _stars = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    _stars >= star ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 40,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 26),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  foregroundColor: Colors.white54,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(l.lessonRatingLater),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (_stars == 0 || _submitting) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.primaryDark,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primaryDark))
                    : Text(l.lessonRatingSubmit,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await CourseService.rateCourse(courseId: widget.courseId, rating: _stars);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }
}
