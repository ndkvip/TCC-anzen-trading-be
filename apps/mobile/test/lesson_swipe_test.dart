import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/core/theme/app_theme.dart';
import 'package:ttc_ict_mobile/data/sample_content.dart';
import 'package:ttc_ict_mobile/features/auth/auth_models.dart';
import 'package:ttc_ict_mobile/features/learning/lesson_screen.dart';

void main() {
  testWidgets('vuốt trái chuyển thẻ và vuốt phải quay lại thẻ trước', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const cards = [
      KnowledgeCard(tag: '01', title: '', body: ''),
      KnowledgeCard(tag: '02', title: '', body: ''),
      KnowledgeCard(tag: '03', title: '', body: ''),
    ];
    const lesson = LessonItem(
      id: 'lesson',
      title: 'Bài học thử',
      description: '',
      duration: '10 phút',
      questionCount: 0,
      tier: LearningTier.basic,
      progress: 0,
      icon: Icons.auto_stories,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LessonScreen(lesson: lesson, cards: cards),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 3'), findsOneWidget);
    final cardSize = tester.getSize(
      find.byKey(const ValueKey('knowledge-swipe-surface')),
    );
    expect(cardSize.width / cardSize.height, closeTo(9 / 16, .001));

    // Height-constrained screens must shrink the width, not distort the card.
    for (final size in [const Size(375, 667), const Size(667, 375)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      final cardRect = tester.getRect(
        find.byKey(const ValueKey('knowledge-swipe-surface')),
      );
      expect(cardRect.width / cardRect.height, closeTo(9 / 16, .001));
      expect(cardRect.left, greaterThanOrEqualTo(20));
      expect(cardRect.right, lessThanOrEqualTo(size.width - 20));
      expect(cardRect.bottom, lessThanOrEqualTo(size.height - 20));
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('knowledge-swipe-surface')),
      const Offset(-350, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 2 / 3'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('knowledge-swipe-surface')),
      const Offset(350, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 3'), findsOneWidget);

    // The completion panel is already in the deck under the final card. It
    // must be visible during the final exit animation, while the final card
    // keeps moving off-screen instead of snapping back to the center.
    for (var index = 1; index < cards.length; index++) {
      await tester.drag(
        find.byKey(const ValueKey('knowledge-swipe-surface')),
        const Offset(-350, 0),
      );
      await tester.pumpAndSettle();
    }
    final surface = find.byKey(const ValueKey('knowledge-swipe-surface'));
    final width = tester.getSize(surface).width;
    final finalSwipe = await tester.startGesture(tester.getCenter(surface));
    await finalSwipe.moveBy(Offset(-width * .72, 0));
    await tester.pump();
    await finalSwipe.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('knowledge-layer-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('knowledge-layer-3')), findsOneWidget);
    final finalCardOffset = tester.widget<Transform>(
      find.byKey(const ValueKey('knowledge-offset-2')),
    );
    expect(finalCardOffset.transform[12], lessThan(0));
    await tester.pumpAndSettle();

    // Swiping past completion must not go beyond the end of the deck.
    await tester.drag(surface, const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Đã xem hết kiến thức'), findsOneWidget);
    expect(find.text('Mở bài tập'), findsOneWidget);
    expect(find.text('Xem lại kiến thức'), findsOneWidget);
    final deck = tester.element(find.byKey(const ValueKey('knowledge-deck')));
    final headerRect = tester.getRect(
      find.byKey(const ValueKey('knowledge-header')),
    );
    final surfaceRect = tester.getRect(surface);
    await tester.tap(find.text('Xem lại kiến thức'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final returningCard = tester.widget<Transform>(
      find.byKey(const ValueKey('knowledge-offset-0')),
    );
    expect(returningCard.transform[12], greaterThan(-width * 1.25));
    expect(returningCard.transform[12], lessThan(0));
    expect(find.text('Xem lại kiến thức').hitTestable(), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 3'), findsOneWidget);
    expect(find.text('Xem lại kiến thức').hitTestable(), findsNothing);
    expect(
      tester.element(find.byKey(const ValueKey('knowledge-deck'))),
      same(deck),
    );
    expect(tester.getRect(surface), surfaceRect);
    expect(
      tester.getRect(find.byKey(const ValueKey('knowledge-header'))),
      headerRect,
    );
    await tester.drag(surface, Offset(width * .7, 0));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 3'), findsOneWidget);
    await tester.drag(surface, Offset(-width * .7, 0));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 2 / 3'), findsOneWidget);
    await tester.drag(surface, Offset(-width * .7, 0));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 3 / 3'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('knowledge-swipe-surface')),
      const Offset(-350, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đã xem hết kiến thức'), findsOneWidget);
    await tester.tap(find.text('Mở bài tập'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn một đáp án đúng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back brings the previous card over a stable deck', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const cards = [
      KnowledgeCard(tag: '01', title: '', body: ''),
      KnowledgeCard(tag: '02', title: '', body: ''),
      KnowledgeCard(tag: '03', title: '', body: ''),
      KnowledgeCard(tag: '04', title: '', body: ''),
    ];
    const lesson = LessonItem(
      id: 'lesson',
      title: 'Bài học thử',
      description: '',
      duration: '',
      questionCount: 0,
      tier: LearningTier.basic,
      progress: 0,
      icon: Icons.auto_stories,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LessonScreen(lesson: lesson, cards: cards),
      ),
    );
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('knowledge-swipe-surface'));
    final deck = tester.element(find.byKey(const ValueKey('knowledge-deck')));
    final width = tester.getSize(surface).width;
    Offset offsetOf(int index) {
      final transform = tester.widget<Transform>(
        find.byKey(ValueKey('knowledge-offset-$index')),
      );
      return Offset(transform.transform[12], transform.transform[13]);
    }

    // Forward swipes promote the next card without a second fade transition.
    await tester.drag(surface, Offset(-width * .7, 0));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 2 / 4'), findsOneWidget);
    expect(
      tester.element(find.byKey(const ValueKey('knowledge-deck'))),
      same(deck),
    );
    expect(offsetOf(1), Offset.zero);

    final gesture = await tester.startGesture(tester.getCenter(surface));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await gesture.moveBy(Offset(width * .45, 0));
    await tester.pump();

    final previousLayer = find.byKey(const ValueKey('knowledge-layer-0'));
    final stack = tester.widget<Stack>(
      find.ancestor(of: previousLayer, matching: find.byType(Stack)).first,
    );
    expect(stack.children.last.key, const ValueKey('knowledge-layer-0'));
    expect(offsetOf(0).dx, lessThan(0));
    expect(offsetOf(0).dx, greaterThan(-width * 1.25));
    expect(offsetOf(1).dx, 0);
    expect(offsetOf(1).dy, greaterThan(0));
    expect(offsetOf(2).dy, greaterThan(11));

    final previousX = offsetOf(0).dx;
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(offsetOf(0).dx, greaterThan(previousX));
    expect(find.text('Thẻ 2 / 4'), findsOneWidget);
    // A second swipe cannot interrupt an already committed transition.
    await tester.drag(surface, Offset(-width * .5, 0));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 4'), findsOneWidget);
    expect(
      tester.element(find.byKey(const ValueKey('knowledge-deck'))),
      same(deck),
    );
    expect(offsetOf(0), Offset.zero);
    expect(offsetOf(1), const Offset(0, 11));

    await tester.drag(surface, Offset(-width * .7, 0));
    await tester.pumpAndSettle();
    final cancelled = await tester.startGesture(tester.getCenter(surface));
    await cancelled.moveBy(const Offset(24, 0));
    await cancelled.moveBy(Offset(width * .1, 0));
    await tester.pump();
    expect(offsetOf(0).dx, lessThan(0));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 2 / 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('knowledge-layer-0')), findsNothing);
    expect(offsetOf(1), Offset.zero);

    // Returning to the first card never creates a negative card index.
    await tester.drag(surface, Offset(width * .7, 0));
    await tester.pumpAndSettle();
    await tester.drag(surface, Offset(width * .7, 0));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 4'), findsOneWidget);
    expect(offsetOf(0), Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports progress while reading and practicing a lesson', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const cards = [
      KnowledgeCard(tag: '01', title: '', body: ''),
      KnowledgeCard(tag: '02', title: '', body: ''),
    ];
    const questions = [
      QuizQuestion(
        question: 'Đáp án nào đúng?',
        options: [QuizOption(text: 'Đúng')],
        correctIndex: 0,
        explanation: '',
      ),
    ];
    const lesson = LessonItem(
      id: 'lesson-progress',
      title: 'Bài học tiến độ',
      description: '',
      duration: '10 phút',
      questionCount: 1,
      tier: LearningTier.basic,
      progress: 0,
      icon: Icons.auto_stories,
    );
    final progress = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LessonScreen(
          lesson: lesson,
          cards: cards,
          questions: questions,
          onProgressChanged: progress.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('knowledge-swipe-surface'));

    await tester.drag(surface, const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(progress, [.25]);

    await tester.drag(surface, const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(progress, [.25, .5]);

    await tester.tap(find.text('Mở bài tập'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quiz-option-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quiz-submit')));
    await tester.pumpAndSettle();
    expect(progress, [.25, .5, 1]);
  });
}
