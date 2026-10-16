import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/sample_content.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.onProgressChanged, this.questions});
  final ValueChanged<double>? onProgressChanged;
  final List<QuizQuestion>? questions;
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  int _question = 0;
  int? _selected;
  bool _checked = false;
  int _score = 0;
  bool _transitioning = false;
  bool _isExiting = false;
  late final AnimationController _questionController;
  final _scrollController = ScrollController();
  GlobalKey _feedbackKey = GlobalKey();

  List<QuizQuestion> get _questions => widget.questions ?? quizQuestions;

  int get _answeredCount => _question + (_checked ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _questionController = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 110),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selected == null || _transitioning) return;
    if (!_checked) {
      setState(() {
        _checked = true;
        if (_selected == _questions[_question].correctIndex) _score += 1;
      });
      widget.onProgressChanged?.call(_answeredCount / _questions.length);
      final question = _question;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _question != question || !_checked || _transitioning) {
          return;
        }
        final feedbackContext = _feedbackKey.currentContext;
        if (feedbackContext == null) return;
        Scrollable.ensureVisible(
          feedbackContext,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
      return;
    }
    if (_question == _questions.length - 1) {
      _showResult();
    } else {
      _advanceQuestion();
    }
  }

  void _replaceQuestion() {
    // Reset scrolling only while the old question is invisible.
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _question += 1;
      _selected = null;
      _checked = false;
      _feedbackKey = GlobalKey();
      _isExiting = false;
    });
  }

  Future<void> _advanceQuestion() async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _replaceQuestion();
      return;
    }
    setState(() {
      _transitioning = true;
      _isExiting = true;
    });
    try {
      await _questionController.reverse().orCancel;
      if (!mounted) return;
      _replaceQuestion();
      await _questionController.forward().orCancel;
      if (mounted) setState(() => _transitioning = false);
    } on TickerCanceled {
      // Leaving the quiz cancels the transition with the controller.
    }
  }

  Future<void> _showResult() async {
    widget.onProgressChanged?.call(1);
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 38,
                color: context.appStatusColors.dark,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Hoàn thành bài tập!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn trả lời đúng $_score/${_questions.length} câu.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Quay lại bài học'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Bài học này chưa có bài tập.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _answeredCount / _questions.length),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 9,
              backgroundColor: AppColors.line,
              color: context.appStatusColors.primary,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_answeredCount/${_questions.length}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _questionController,
                  builder: (context, child) {
                    final opacity =
                        (_isExiting ? Curves.easeInCubic : Curves.easeOutCubic)
                            .transform(_questionController.value);
                    return IgnorePointer(
                      ignoring: _transitioning,
                      child: ExcludeSemantics(
                        excluding: _transitioning,
                        child: Opacity(
                          key: const ValueKey('quiz-question-opacity'),
                          opacity: opacity,
                          child: Transform.translate(
                            key: const ValueKey('quiz-question-offset'),
                            offset: Offset(
                              (_isExiting ? -14 : 16) * (1 - opacity),
                              0,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                  child: RepaintBoundary(
                    child: _buildQuestionContent(_question),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: const Border(top: BorderSide(color: AppColors.line)),
              ),
              child: FilledButton(
                key: const ValueKey('quiz-submit'),
                onPressed: _selected == null || _transitioning ? null : _submit,
                child: Text(
                  _checked
                      ? (_question == _questions.length - 1
                            ? 'Xem kết quả'
                            : 'Câu tiếp theo')
                      : 'Kiểm tra',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionContent(int question) {
    final item = _questions[question];
    return SingleChildScrollView(
      key: const ValueKey('quiz-content-scroll'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        key: ValueKey('question-$question'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Câu ${question + 1}',
                    style: TextStyle(
                      color: context.appStatusColors.dark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (item.question.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.question,
                    key: const ValueKey('quiz-question-text'),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 19,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (item.imagePath != null || item.imageLabel != null) ...[
                  const SizedBox(height: 14),
                  _QuizMedia(
                    imagePath: item.imagePath,
                    imageUrl: item.imageLabel,
                    semanticLabel: 'Ảnh câu hỏi ${question + 1}',
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 12),
            child: Text(
              'Chọn một đáp án đúng',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (var index = 0; index < item.options.length; index++)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
              child: _buildOption(item, index),
            ),
          if (_checked && question == _question) ...[
            const SizedBox(height: 18),
            Container(
              key: _feedbackKey,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    (_selected == item.correctIndex
                            ? AppColors.lime
                            : AppColors.coral)
                        .withValues(alpha: .18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selected == item.correctIndex ? 'Chính xác!' : 'Chưa đúng',
                    style: TextStyle(
                      color: _selected == item.correctIndex
                          ? context.appStatusColors.dark
                          : AppColors.coral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.explanation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.explanation,
                      style: const TextStyle(
                        color: AppColors.ink,
                        height: 1.55,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(QuizQuestion item, int index) {
    final option = item.options[index];
    final selected = _selected == index;
    final correct = _checked && index == item.correctIndex;
    final wrong = _checked && selected && index != item.correctIndex;
    final borderColor = correct || selected && !wrong
        ? context.appStatusColors.primary
        : wrong
        ? AppColors.coral
        : AppColors.line;
    final fill = correct
        ? AppColors.lime.withValues(alpha: .25)
        : wrong
        ? AppColors.coral.withValues(alpha: .09)
        : AppColors.surface;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        key: ValueKey('quiz-option-$index'),
        onTap: _checked || _transitioning
            ? null
            : () {
                if (!_transitioning) setState(() => _selected = index);
              },
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: borderColor,
              width: selected || correct ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected || correct
                      ? borderColor
                      : const Color(0xFFE7EFF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: selected || correct ? Colors.white : AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (option.text?.isNotEmpty ?? false)
                      Text(
                        option.text!,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    if (option.imagePath != null ||
                        option.imageLabel != null) ...[
                      if (option.text?.isNotEmpty ?? false)
                        const SizedBox(height: 9),
                      _QuizMedia(
                        imagePath: option.imagePath,
                        imageUrl: option.imageLabel,
                        semanticLabel: 'Ảnh đáp án ${index + 1}',
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
              if (correct || wrong)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Icon(
                    correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: correct
                        ? context.appStatusColors.primary
                        : AppColors.coral,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizMedia extends StatelessWidget {
  const _QuizMedia({
    this.imagePath,
    this.imageUrl,
    required this.semanticLabel,
    this.compact = false,
  });
  final String? imagePath;
  final String? imageUrl;
  final String semanticLabel;
  final bool compact;

  Widget _fallback(BuildContext context) => Container(
    alignment: Alignment.center,
    color: compact
        ? const Color(0xFFE7EFF4)
        : context.appStatusColors.primary.withValues(alpha: .08),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.broken_image_outlined,
          color: context.appStatusColors.primary,
          size: compact ? 22 : 28,
        ),
        const SizedBox(height: 6),
        const Text(
          'Không mở được ảnh',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final localPath = imagePath;
    final remoteUrl = imageUrl;
    final Widget image;
    if (localPath != null && File(localPath).existsSync()) {
      image = Image.file(
        File(localPath),
        key: ValueKey('quiz-media-local-$localPath'),
        fit: BoxFit.contain,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    } else if (remoteUrl != null &&
        (remoteUrl.startsWith('http://') || remoteUrl.startsWith('https://'))) {
      image = Image.network(
        remoteUrl,
        key: ValueKey('quiz-media-network-$remoteUrl'),
        fit: BoxFit.contain,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    } else {
      image = _fallback(context);
    }

    return Container(
      key: ValueKey(semanticLabel),
      width: double.infinity,
      height: compact ? 96 : 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: compact
            ? const Color(0xFFE7EFF4)
            : context.appStatusColors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: compact
              ? AppColors.line
              : context.appStatusColors.primary.withValues(alpha: .18),
        ),
      ),
      child: image,
    );
  }
}
