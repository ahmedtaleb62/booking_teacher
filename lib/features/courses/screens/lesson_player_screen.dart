import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/services/course_service.dart';

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
    if (!_isQuiz) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (widget.videoUrl != null) _initWebView(_resolveUrl(widget.videoUrl!));
    }
  }

  @override
  void dispose() {
    if (!_isQuiz) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  String _resolveUrl(String url) {
    final isFile = widget.lessonType == 'file' || widget.lessonType == 'summary';
    final isVideo = url.contains('youtube.com') || url.contains('youtu.be');
    if (isFile && !isVideo) {
      return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true';
    }
    return url;
  }

  void _initWebView(String url) {
    _webCtrl = WebViewController(
      onPermissionRequest: (req) => req.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _webReady = true),
      ))
      ..loadRequest(Uri.parse(url));
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
            child: widget.videoUrl != null && _webCtrl != null
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
                      Positioned(
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
                      ),
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
