import 'dart:io';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/sample_content.dart';
import 'quiz_screen.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.lesson,
    this.onProgressChanged,
    this.cards,
    this.questions,
  });
  final LessonItem lesson;
  final ValueChanged<double>? onProgressChanged;
  final List<KnowledgeCard>? cards;
  final List<QuizQuestion>? questions;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  Future<void> _openPractice() async {
    final questions = widget.questions ?? quizQuestions;
    if (questions.isEmpty) {
      widget.onProgressChanged?.call(1);
      return;
    }
    // Keep the lesson card in sync even when a lesson has no knowledge cards.
    if ((widget.cards ?? knowledgeCards).isEmpty) {
      widget.onProgressChanged?.call(.5);
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          questions: questions,
          onProgressChanged: (quizProgress) {
            // The lesson is split between knowledge cards and practice.
            widget.onProgressChanged?.call(
              .5 + quizProgress.clamp(0.0, 1.0) * .5,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton.filledTonal(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewPaddingOf(context).bottom + 20,
        ),
        child: _KnowledgeDeck(
          lesson: widget.lesson,
          cards: widget.cards,
          hasPractice: (widget.questions ?? quizQuestions).isNotEmpty,
          onProgressChanged: widget.onProgressChanged,
          onStartPractice: _openPractice,
        ),
      ),
    ),
  );
}

class _KnowledgeDeck extends StatefulWidget {
  const _KnowledgeDeck({
    required this.lesson,
    required this.onStartPractice,
    required this.hasPractice,
    this.onProgressChanged,
    this.cards,
  });
  final LessonItem lesson;
  final VoidCallback onStartPractice;
  final bool hasPractice;
  final ValueChanged<double>? onProgressChanged;
  final List<KnowledgeCard>? cards;
  @override
  State<_KnowledgeDeck> createState() => _KnowledgeDeckState();
}

class _KnowledgeDeckState extends State<_KnowledgeDeck>
    with SingleTickerProviderStateMixin {
  static const _swipeExtent = 1.25;

  int _index = 0;
  List<KnowledgeCard> get _cards => widget.cards ?? knowledgeCards;
  double _dragX = 0;
  bool _isDragging = false;
  bool _reviewFromStart = false;
  late final AnimationController _dragController;
  double _animationStart = 0;
  double _animationEnd = 0;
  VoidCallback? _animationComplete;

  @override
  void initState() {
    super.initState();
    _dragController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 260),
          )
          ..addListener(() {
            if (!mounted) return;
            setState(() {
              final progress = Curves.easeOutCubic.transform(
                _dragController.value,
              );
              _dragX =
                  _animationStart +
                  (_animationEnd - _animationStart) * progress;
            });
          })
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed) return;
            final onComplete = _animationComplete;
            _animationComplete = null;
            onComplete?.call();
          });
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _animateTo(double target, {VoidCallback? onComplete}) {
    _dragController.stop();
    _animationStart = _dragX;
    _animationEnd = target;
    _animationComplete = onComplete;
    _dragController
      ..duration = Duration(milliseconds: target == 0 ? 280 : 230)
      ..reset()
      ..forward();
  }

  void _finishSwipe(double width) {
    if (_cards.isEmpty) return;
    final direction = _dragX.sign;
    if (_dragX.abs() < width * .22) {
      setState(() => _isDragging = false);
      _animateTo(0);
      return;
    }

    // Left advances the deck; right reveals the card that was just viewed.
    // The completion panel is the last item in the same stack.
    final isNext = direction < 0;
    if ((!isNext && _index == 0) || (isNext && _index == _cards.length)) {
      setState(() => _isDragging = false);
      _animateTo(0);
      return;
    }

    setState(() => _isDragging = false);
    _animateTo(
      (isNext ? -1 : 1) * width * _swipeExtent,
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _index += isNext ? 1 : -1;
          _dragX = 0;
        });
        if (isNext && _cards.isNotEmpty) {
          // Knowledge cards account for the first half of the lesson.
          widget.onProgressChanged?.call(
            ((_index / _cards.length) * (widget.hasPractice ? .5 : 1.0)).clamp(
              0.0,
              1.0,
            ),
          );
        }
      },
    );
  }

  void _restartKnowledge(double width) {
    if (_cards.isEmpty ||
        _index != _cards.length ||
        _dragController.isAnimating ||
        _animationComplete != null) {
      return;
    }
    setState(() => _reviewFromStart = true);
    _animateTo(
      width * _swipeExtent,
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _index = 0;
          _dragX = 0;
          _reviewFromStart = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardIndex = _index;
    final complete = cardIndex >= _cards.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Keep both header layouts measured so completion cannot resize the
        // portrait deck halfway through the final swipe.
        Stack(
          key: const ValueKey('knowledge-header'),
          alignment: Alignment.centerLeft,
          children: [
            ExcludeSemantics(
              excluding: complete,
              child: AnimatedOpacity(
                opacity: complete ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thẻ ${_index + 1} / ${_cards.length}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          'Vuốt trái: tiếp theo · phải: quay lại',
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ExcludeSemantics(
              excluding: !complete,
              child: AnimatedOpacity(
                opacity: complete ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Text(
                  'Đã xem hết kiến thức',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Align(
            key: const ValueKey('knowledge-deck'),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  key: const ValueKey('knowledge-swipe-surface'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    if (_cards.isEmpty ||
                        _dragController.isAnimating ||
                        _animationComplete != null) {
                      return;
                    }
                    _dragController.stop();
                    setState(() => _isDragging = true);
                  },
                  onHorizontalDragUpdate: (details) {
                    if (!_isDragging) return;
                    setState(() {
                      _dragX = (_dragX + details.delta.dx).clamp(
                        -constraints.maxWidth,
                        constraints.maxWidth,
                      );
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    if (_isDragging) _finishSwipe(constraints.maxWidth);
                  },
                  onHorizontalDragCancel: () {
                    if (!_isDragging) return;
                    setState(() => _isDragging = false);
                    _animateTo(0);
                  },
                  child: _buildCards(
                    index: cardIndex,
                    width: constraints.maxWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCards({required int index, required double width}) {
    final extent = width * _swipeExtent;
    final nextProgress = (-_dragX / extent).clamp(0.0, 1.0);
    final previousProgress = index > 0
        ? (_dragX / extent).clamp(0.0, 1.0)
        : 0.0;
    final goingBack = previousProgress > 0;

    if (_reviewFromStart) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          _buildCardLayer(
            index: index,
            width: width,
            depth: previousProgress * (_cards.length <= 3 ? _cards.length : 1),
            visibility: _cards.length <= 3 ? 1 : 1 - previousProgress,
          ),
          for (var depth = 3; depth >= 1; depth--)
            if (depth < _cards.length)
              _buildCardLayer(
                index: depth,
                width: width,
                depth: depth + 1 - previousProgress,
                visibility: previousProgress,
              ),
          _buildCardLayer(
            index: 0,
            width: width,
            horizontalOffset: _dragX - extent,
            angle: ((_dragX - extent) / width) * .10,
          ),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var depth = 3; depth >= 1; depth--)
          if (index + depth <= _cards.length)
            _buildCardLayer(
              index: index + depth,
              width: width,
              depth: depth - nextProgress + previousProgress,
            ),
        _buildCardLayer(
          index: index,
          width: width,
          depth: previousProgress,
          horizontalOffset: goingBack ? 0 : _dragX,
          angle: goingBack ? 0 : (_dragX / width) * .10,
          isDragging: _isDragging && !goingBack,
        ),
        // Reverse the forward swipe: bring the previous card in from the
        // left above the deck, while the current card settles underneath.
        if (goingBack)
          _buildCardLayer(
            index: index - 1,
            width: width,
            horizontalOffset: _dragX - extent,
            angle: ((_dragX - extent) / width) * .10,
            isDragging: _isDragging,
          ),
      ],
    );
  }

  Widget _buildCardLayer({
    required int index,
    required double width,
    double depth = 0,
    double horizontalOffset = 0,
    double angle = 0,
    double visibility = 1,
    bool isDragging = false,
  }) {
    final isCompletion = index == _cards.length;
    final opacity = depth <= 1
        ? 1 - .38 * depth
        : depth < 2
        ? .62 - .20 * (depth - 1)
        : .42;

    return Positioned.fill(
      key: ValueKey('knowledge-layer-$index'),
      child: ExcludeSemantics(
        excluding: index != _index,
        child: IgnorePointer(
          ignoring:
              !isCompletion ||
              index != _index ||
              _isDragging ||
              _dragController.isAnimating,
          child: Transform.translate(
            key: ValueKey('knowledge-offset-$index'),
            offset: Offset(horizontalOffset, depth * 11),
            child: Transform.rotate(
              key: ValueKey('knowledge-rotation-$index'),
              angle: angle,
              child: Transform.scale(
                key: ValueKey('knowledge-scale-$index'),
                scale: 1 - depth * .035,
                child: Opacity(
                  opacity: opacity * visibility,
                  child: isCompletion
                      ? SingleChildScrollView(
                          key: const ValueKey('knowledge-complete'),
                          child: _KnowledgeComplete(
                            onStartPractice: widget.onStartPractice,
                            onBackToKnowledge: _cards.isEmpty
                                ? null
                                : () => _restartKnowledge(width),
                          ),
                        )
                      : _DeckCard(
                          card: _cards[index],
                          lesson: index == 0 ? widget.lesson : null,
                          isDragging: isDragging,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.card, this.lesson, this.isDragging = false});
  final KnowledgeCard card;
  final LessonItem? lesson;
  final bool isDragging;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.appStatusColors.dark,
      borderRadius: BorderRadius.circular(27),
      boxShadow: [
        BoxShadow(
          color: context.appStatusColors.primary.withValues(
            alpha: isDragging ? .28 : .18,
          ),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: card.imagePath != null
        ? Image.file(
            File(card.imagePath!),
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 40,
              ),
            ),
          )
        : card.imageLabel != null &&
              (card.imageLabel!.startsWith('http://') ||
                  card.imageLabel!.startsWith('https://'))
        ? Image.network(
            card.imageLabel!,
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 40,
              ),
            ),
          )
        : const Center(
            child: Text(
              'Bài học chưa có ảnh',
              style: TextStyle(color: Colors.white),
            ),
          ),
  );
}

class _KnowledgeComplete extends StatelessWidget {
  const _KnowledgeComplete({
    required this.onStartPractice,
    this.onBackToKnowledge,
  });
  final VoidCallback onStartPractice;
  final VoidCallback? onBackToKnowledge;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.lime.withValues(alpha: .28),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: context.appStatusColors.primary.withValues(alpha: .18),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: context.appStatusColors.primary,
          size: 38,
        ),
        const SizedBox(height: 15),
        Text(
          'Bạn đã xem hết phần kiến thức',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 7),
        const Text(
          'Bây giờ hãy kiểm tra lại nội dung bằng 3 lựa chọn cho mỗi câu hỏi. Câu hỏi và đáp án có thể là chữ hoặc hình ảnh.',
          style: TextStyle(color: AppColors.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onStartPractice,
          icon: const Icon(Icons.quiz_outlined),
          label: const Text('Mở bài tập'),
        ),
        if (onBackToKnowledge != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onBackToKnowledge,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Xem lại kiến thức'),
          ),
        ],
      ],
    ),
  );
}
