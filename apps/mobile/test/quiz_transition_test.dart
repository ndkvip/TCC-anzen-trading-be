import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/core/theme/app_theme.dart';
import 'package:ttc_ict_mobile/data/sample_content.dart';
import 'package:ttc_ict_mobile/features/learning/quiz_screen.dart';

const _submitKey = ValueKey('quiz-submit');
const _scrollKey = ValueKey('quiz-content-scroll');
const _opacityKey = ValueKey('quiz-question-opacity');
const _offsetKey = ValueKey('quiz-question-offset');

final _questions = [
  QuizQuestion(
    question: List.filled(10, 'A long question with several lines.').join('\n'),
    options: const [
      QuizOption(text: 'The correct answer.'),
      QuizOption(text: 'Another answer.'),
    ],
    correctIndex: 0,
    explanation: List.filled(
      6,
      'Explanation of the correct answer.',
    ).join('\n'),
  ),
  const QuizQuestion(
    question: 'A short second question.',
    options: [
      QuizOption(text: 'First answer.'),
      QuizOption(text: 'Second answer.'),
    ],
    correctIndex: 0,
    explanation: 'Second explanation.',
  ),
  const QuizQuestion(
    question: 'The third question.',
    options: [QuizOption(text: 'An answer.')],
    correctIndex: 0,
    explanation: 'Third explanation.',
  ),
];

Future<void> _pumpQuiz(
  WidgetTester tester, {
  bool reducedMotion = false,
  ValueChanged<double>? onProgressChanged,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 667));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: QuizScreen(
        questions: _questions,
        onProgressChanged: onProgressChanged,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _checkFirstQuestion(WidgetTester tester) async {
  final option = find.byKey(const ValueKey('quiz-option-0'));
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_submitKey));
  await tester.pumpAndSettle();
}

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byKey(_opacityKey)).opacity;

double _translation(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(_offsetKey)).transform.storage[12];

void main() {
  testWidgets('fade-through preserves old scroll and keeps the footer fixed', (
    tester,
  ) async {
    final progress = <double>[];
    await _pumpQuiz(tester, onProgressChanged: progress.add);
    await _checkFirstQuestion(tester);
    final controller = tester
        .widget<SingleChildScrollView>(find.byKey(_scrollKey))
        .controller!;
    final oldOffset = controller.offset;
    final footer = tester.getRect(find.byKey(_submitKey));
    expect(oldOffset, greaterThan(0));
    expect(progress, [1 / 3]);

    await tester.tap(find.byKey(_submitKey));
    await tester.pump();
    expect(find.byKey(const ValueKey('question-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('question-1')), findsNothing);
    expect(controller.offset, oldOffset);

    await tester.pump(const Duration(milliseconds: 55));
    expect(_opacity(tester), inExclusiveRange(0, 1));
    expect(_translation(tester), lessThan(0));
    expect(controller.offset, oldOffset);
    expect(tester.getRect(find.byKey(_submitKey)), footer);
    expect(find.byKey(const ValueKey('question-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('question-1')), findsNothing);

    await tester.pump(const Duration(milliseconds: 56));
    expect(_opacity(tester), 0);
    // Flush the controller completion future before sampling the new child.
    await tester.pump();
    expect(controller.offset, 0);
    expect(find.byKey(const ValueKey('question-0')), findsNothing);
    expect(find.byKey(const ValueKey('question-1')), findsOneWidget);
    expect(_translation(tester), 16);
    expect(tester.getRect(find.byKey(_submitKey)), footer);

    await tester.pump(const Duration(milliseconds: 125));
    expect(_opacity(tester), inExclusiveRange(0, 1));
    expect(_translation(tester), inExclusiveRange(0, 16));
    expect(controller.offset, 0);
    expect(tester.getRect(find.byKey(_submitKey)), footer);
    expect(find.text('1/3'), findsOneWidget);
    expect(progress, [1 / 3]);

    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    expect(_translation(tester), 0);
    expect(find.text(_questions[1].question).hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byKey(_submitKey)), footer);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated next taps and answer selection are locked in motion', (
    tester,
  ) async {
    await _pumpQuiz(tester);
    await _checkFirstQuestion(tester);
    final next = tester.widget<FilledButton>(find.byKey(_submitKey)).onPressed!;

    // Exercise a stale callback too, before the disabled button rebuilds.
    next();
    next();
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(_submitKey)).onPressed,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byKey(const ValueKey('question-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('question-2')), findsNothing);
    for (final option in tester.widgetList<InkWell>(
      find.byKey(const ValueKey('quiz-option-0')),
    )) {
      expect(option.onTap, isNull);
    }
    next();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('question-1')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(_submitKey)).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('quiz-option-0')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(_submitKey)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion switches directly with no scroll or fade delay', (
    tester,
  ) async {
    await _pumpQuiz(tester, reducedMotion: true);
    await _checkFirstQuestion(tester);
    final controller = tester
        .widget<SingleChildScrollView>(find.byKey(_scrollKey))
        .controller!;
    expect(controller.offset, greaterThan(0));
    await tester.tap(find.byKey(_submitKey));
    await tester.pump();

    expect(find.byKey(const ValueKey('question-0')), findsNothing);
    expect(find.byKey(const ValueKey('question-1')), findsOneWidget);
    expect(
      tester
          .widget<SingleChildScrollView>(find.byKey(_scrollKey))
          .controller!
          .offset,
      0,
    );
    expect(_opacity(tester), 1);
    expect(_translation(tester), 0);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('quiz-option-0'))).onTap,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final elapsed in [60, 220]) {
    testWidgets('disposing during transition at ${elapsed}ms cancels safely', (
      tester,
    ) async {
      await _pumpQuiz(tester);
      await _checkFirstQuestion(tester);
      await tester.tap(find.byKey(_submitKey));
      await tester.pump();
      await tester.pump(Duration(milliseconds: elapsed < 110 ? elapsed : 110));
      if (elapsed > 110) {
        await tester.pump();
        await tester.pump(Duration(milliseconds: elapsed - 110));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });
  }
}
