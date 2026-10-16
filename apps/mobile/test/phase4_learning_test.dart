import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttc_ict_mobile/core/network/api_client.dart';
import 'package:ttc_ict_mobile/core/theme/app_theme.dart';
import 'package:ttc_ict_mobile/data/sample_content.dart';
import 'package:ttc_ict_mobile/features/auth/auth_controller.dart';
import 'package:ttc_ict_mobile/features/auth/auth_models.dart';
import 'package:ttc_ict_mobile/features/learning/learning_repository.dart';
import 'package:ttc_ict_mobile/features/learning/quiz_screen.dart';

AuthController authenticatedUser() => AuthController()
  ..accessToken = 'phase-4-token'
  ..user = const AppUser(
    id: 'phase-4-user',
    email: 'student@example.com',
    name: 'Học viên',
    role: UserRole.student,
    accountTier: AccountTier.vip2,
    isActive: true,
  );

void main() {
  test('lesson question and answer images remain available offline', () async {
    final root = await Directory.systemTemp.createTemp('anzen-phase4-');
    addTearDown(() => root.delete(recursive: true));
    const lessonId = '11111111-1111-4111-8111-111111111111';
    const knowledgeUrl =
        '/learning/lessons/$lessonId/images/22222222-2222-4222-8222-222222222222.webp';
    const questionUrl =
        '/learning/lessons/$lessonId/exercise-images/33333333-3333-4333-8333-333333333333.webp';
    const answerUrl =
        '/learning/lessons/$lessonId/exercise-images/44444444-4444-4444-8444-444444444444.webp';
    final lessonList = [
      {
        'id': lessonId,
        'slug': 'phase-4',
        'title': 'Bài học ảnh',
        'description': '',
        'tier': 'BASIC',
        'position': 0,
        'durationMinutes': 10,
        'questionCount': 1,
        'locked': false,
        'progress': 0,
      },
    ];
    final lessonDetail = {
      ...lessonList.first,
      'knowledgeCards': [
        {'imageUrl': knowledgeUrl},
      ],
      'questions': [
        {
          'question': 'Chọn đáp án đúng',
          'imageUrl': questionUrl,
          'options': [
            {'text': 'Một'},
            {'imageUrl': answerUrl},
            {'text': 'Ba'},
          ],
          'correctIndex': 1,
          'explanation': 'Đáp án hình ảnh.',
        },
      ],
    };
    final onlineClient = MockClient((request) async {
      if (request.url.path == '/api/learning/lessons') {
        return http.Response(
          jsonEncode(lessonList),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/learning/lessons/$lessonId') {
        return http.Response(
          jsonEncode(lessonDetail),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('.webp')) {
        return http.Response.bytes([1, 2, 3, 4], 200);
      }
      return http.Response('{}', 404);
    });
    final auth = authenticatedUser();
    final onlineRepository = LearningRepository(
      auth: auth,
      api: ApiClient(client: onlineClient),
      documentsDirectory: () async => root,
    );

    final online = await onlineRepository.load();
    expect(online, hasLength(1));
    expect(await File(online.single.cards.single.imagePath!).exists(), isTrue);
    expect(
      await File(online.single.questions.single.imagePath!).exists(),
      isTrue,
    );
    expect(
      await File(online.single.questions.single.options[1].imagePath!).exists(),
      isTrue,
    );

    // A Drive file replacement must not reuse the old cache entry just
    // because both download URLs use the same `/uc` path.
    const updatedKnowledgeUrl =
        '/learning/lessons/$lessonId/images/99999999-9999-4999-8999-999999999999.webp';
    final updatedClient = MockClient((request) async {
      if (request.url.path == '/api/learning/lessons') {
        return http.Response(
          jsonEncode(lessonList),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/learning/lessons/$lessonId') {
        return http.Response(
          jsonEncode({
            ...lessonDetail,
            'knowledgeCards': [
              {'imageUrl': updatedKnowledgeUrl},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('.webp')) {
        return http.Response.bytes([9, 8, 7], 200);
      }
      return http.Response('{}', 404);
    });
    final updated = await LearningRepository(
      auth: auth,
      api: ApiClient(client: updatedClient),
      documentsDirectory: () async => root,
    ).load();
    expect(
      updated.single.cards.single.imagePath,
      isNot(equals(online.single.cards.single.imagePath)),
    );
    expect(await File(updated.single.cards.single.imagePath!).readAsBytes(), [
      9,
      8,
      7,
    ]);

    final offlineRepository = LearningRepository(
      auth: auth,
      api: ApiClient(
        client: MockClient((_) async => throw const SocketException('offline')),
      ),
      documentsDirectory: () async => root,
    );
    final offline = await offlineRepository.load();

    expect(offline.single.questions.single.question, 'Chọn đáp án đúng');
    expect(offline.single.questions.single.options[1].imageLabel, answerUrl);
    expect(
      await File(
        offline.single.questions.single.options[1].imagePath!,
      ).exists(),
      isTrue,
    );
  });

  test(
    'authenticated account without cache does not receive demo lessons',
    () async {
      final root = await Directory.systemTemp.createTemp('anzen-phase4-empty-');
      addTearDown(() => root.delete(recursive: true));
      final repository = LearningRepository(
        auth: authenticatedUser(),
        api: ApiClient(
          client: MockClient(
            (_) async => throw const SocketException('offline'),
          ),
        ),
        documentsDirectory: () async => root,
      );

      expect(await repository.load(), isEmpty);
    },
  );

  testWidgets('quiz renders question and answer media and completes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final progress = <double>[];
    final questions = [
      QuizQuestion(
        question: 'Chọn biểu đồ đúng',
        imagePath: '/missing-question.webp',
        options: [
          const QuizOption(text: 'Sai'),
          const QuizOption(imagePath: '/missing-answer.webp'),
          const QuizOption(text: 'Không phù hợp'),
        ],
        correctIndex: 1,
        explanation: 'Đây là đáp án đúng.',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: QuizScreen(questions: questions, onProgressChanged: progress.add),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('Ảnh câu hỏi 1')), findsOneWidget);
    expect(find.byKey(const ValueKey('Ảnh đáp án 2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-option-1')));
    await tester.pump();
    await tester.tap(find.text('Kiểm tra'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(progress, [1]);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Chính xác!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
