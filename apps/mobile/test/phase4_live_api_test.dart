import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttc_ict_mobile/core/network/api_client.dart';
import 'package:ttc_ict_mobile/features/auth/auth_controller.dart';
import 'package:ttc_ict_mobile/features/auth/auth_models.dart';
import 'package:ttc_ict_mobile/features/learning/learning_repository.dart';

const _token = String.fromEnvironment('PHASE4_ACCESS_TOKEN');
const _userId = String.fromEnvironment('PHASE4_USER_ID');
const _lessonId = String.fromEnvironment('PHASE4_LESSON_ID');

void main() {
  test(
    'downloads a live lesson and reopens every media type offline',
    () async {
      final root = await Directory.systemTemp.createTemp('anzen-phase4-live-');
      addTearDown(() => root.delete(recursive: true));
      final auth = AuthController()
        ..accessToken = _token
        ..user = const AppUser(
          id: _userId,
          email: 'phase4-live@anzen.local',
          name: 'Phase 4 live test',
          role: UserRole.admin,
          accountTier: AccountTier.vip2,
          isActive: true,
        );

      final onlineRepository = LearningRepository(
        auth: auth,
        documentsDirectory: () async => root,
      );
      final onlineLessons = await onlineRepository.load();
      final lesson = onlineLessons.singleWhere(
        (item) => item.item.id == _lessonId,
      );

      expect(lesson.cards, isNotEmpty);
      expect(lesson.questions, isNotEmpty);
      expect(lesson.questions.single.options, hasLength(3));
      expect(await File(lesson.cards.single.imagePath!).exists(), isTrue);
      expect(await File(lesson.questions.single.imagePath!).exists(), isTrue);
      expect(
        await File(lesson.questions.single.options[1].imagePath!).exists(),
        isTrue,
      );

      final offlineRepository = LearningRepository(
        auth: auth,
        api: ApiClient(
          client: MockClient(
            (_) async => throw const SocketException('offline'),
          ),
        ),
        documentsDirectory: () async => root,
      );
      final offlineLessons = await offlineRepository.load();
      final offlineLesson = offlineLessons.singleWhere(
        (item) => item.item.id == _lessonId,
      );

      expect(offlineLesson.questions.single.question, isNotEmpty);
      expect(
        await File(offlineLesson.cards.single.imagePath!).exists(),
        isTrue,
      );
      expect(
        await File(offlineLesson.questions.single.imagePath!).exists(),
        isTrue,
      );
      expect(
        await File(
          offlineLesson.questions.single.options[1].imagePath!,
        ).exists(),
        isTrue,
      );
    },
    skip: _token.isEmpty || _userId.isEmpty || _lessonId.isEmpty
        ? 'Requires a running local API and Phase 4 dart-defines.'
        : false,
  );
}
