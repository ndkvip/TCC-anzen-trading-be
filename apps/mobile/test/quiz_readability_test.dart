import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/core/theme/app_theme.dart';
import 'package:ttc_ict_mobile/data/sample_content.dart';
import 'package:ttc_ict_mobile/features/learning/quiz_screen.dart';

void main() {
  const prompt =
      'Trụ cột 3 (Tâm lý & Kỷ luật) chiếm tỷ trọng lớn nhất (40%).\n\n'
      'Trong trường hợp thị trường biến động mạnh, bạn đã có kế hoạch giao '
      'dịch nhưng giá chưa chạm vùng quan sát và chưa có tín hiệu xác nhận. '
      'Bạn cần làm gì để kiểm soát cảm xúc, tránh FOMO và tuân thủ kế hoạch?';
  final questions = [
    const QuizQuestion(
      question: prompt,
      imagePath: '/missing-chart.webp',
      options: [
        QuizOption(text: 'Vào lệnh ngay vì sợ bỏ lỡ cơ hội.'),
        QuizOption(
          text: 'Tăng khối lượng giao dịch để bù cho lệnh thua trước.',
        ),
        QuizOption(
          text:
              'Kiên nhẫn chờ giá về vùng quan sát, kiểm tra tín hiệu xác nhận '
              'và chỉ thực hiện giao dịch khi các điều kiện trong kế hoạch '
              'đã được đáp ứng.',
        ),
      ],
      correctIndex: 2,
      explanation:
          'Kỷ luật giúp bạn kiểm soát cảm xúc và không vào lệnh chỉ vì sợ bỏ '
          'lỡ cơ hội. Hãy chờ đủ điều kiện đã ghi trong kế hoạch, kiểm tra '
          'rủi ro và giữ nguyên giới hạn khối lượng của mình.\n\n'
          'Không có tín hiệu phù hợp thì không cần thực hiện giao dịch.',
    ),
    const QuizQuestion(
      question: 'Trước khi vào lệnh, bạn cần xác định điều gì?',
      options: [
        QuizOption(text: 'Điểm vô hiệu và rủi ro tối đa.'),
        QuizOption(text: 'Lợi nhuận chắc chắn đạt được.'),
        QuizOption(text: 'Cách dời stop để tránh thua lỗ.'),
      ],
      correctIndex: 0,
      explanation: 'Xác định rủi ro trước khi thực hiện giao dịch.',
    ),
  ];

  for (final size in [const Size(375, 667), const Size(667, 375)]) {
    testWidgets('long questions remain readable and scrollable at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final progress = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: QuizScreen(
            questions: questions,
            onProgressChanged: progress.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final question = tester.widget<Text>(
        find.byKey(const ValueKey('quiz-question-text')),
      );
      expect(question.data, prompt);
      expect(question.maxLines, isNull);
      expect(question.style!.fontSize, 19);
      expect(question.style!.height, greaterThanOrEqualTo(1.5));
      expect(question.style!.fontWeight, FontWeight.w600);
      expect(find.text('Câu 1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('quiz-content-scroll')),
      );
      final buttonRect = tester.getRect(
        find.byKey(const ValueKey('quiz-submit')),
      );
      expect(buttonRect.bottom, lessThanOrEqualTo(size.height));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('quiz-submit')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('quiz-option-2')));
      await tester.pumpAndSettle();
      expect(scrollView.controller!.offset, greaterThan(0));
      expect(
        tester.getRect(find.byKey(const ValueKey('quiz-submit'))),
        buttonRect,
      );
      await tester.tap(find.byKey(const ValueKey('quiz-option-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiểm tra'));
      await tester.pumpAndSettle();
      expect(progress, [.5]);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Chính xác!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(const ValueKey('quiz-submit'))),
        buttonRect,
      );
      // Checked answers cannot be changed, even after scrolling back to them.
      await tester.ensureVisible(find.byKey(const ValueKey('quiz-option-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quiz-option-0')));
      await tester.pumpAndSettle();
      expect(find.text('Chưa đúng'), findsNothing);

      await tester.tap(find.text('Câu tiếp theo'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SingleChildScrollView>(
              find.byKey(const ValueKey('quiz-content-scroll')),
            )
            .controller!
            .offset,
        0,
      );
      expect(find.text('Câu 2'), findsOneWidget);
      expect(find.text(questions[1].question).hitTestable(), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('quiz-submit')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('quiz progress, wrong answers and final result still work', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final progress = <double>[];
    final shortQuestions = [questions[1], questions[1]];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: QuizScreen(
          questions: shortQuestions,
          onProgressChanged: progress.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quiz-option-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa đúng'), findsOneWidget);
    expect(progress, [.5]);
    await tester.tap(find.text('Câu tiếp theo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quiz-option-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra'));
    await tester.pumpAndSettle();
    expect(progress, [.5, 1]);
    expect(find.text('2/2'), findsOneWidget);
    await tester.tap(find.text('Xem kết quả'));
    await tester.pumpAndSettle();
    expect(find.text('Hoàn thành bài tập!'), findsOneWidget);
    expect(find.text('Bạn trả lời đúng 1/2 câu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
