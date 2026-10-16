import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttc_ict_mobile/core/network/api_client.dart';
import 'package:ttc_ict_mobile/features/learning/learning_repository.dart';

import 'phase4_learning_test.dart' show authenticatedUser;

const lessonId = '11111111-1111-4111-8111-111111111111';
const driveId = 'existingDriveFile123';
const driveUrl = 'https://drive.google.com/uc?export=download&id=$driveId';

Map<String, dynamic> lesson(int revision) => {
  'id': lessonId,
  'title': 'Lesson $revision',
  'description': 'Description $revision',
  'tier': 'BASIC',
  'updatedAt': '2026-10-04T00:00:00.000Z',
  'contentVersion': 'content-revision-$revision',
  'locked': false,
  'questionCount': 1,
  'progress': .5,
  'knowledgeCards': [
    {'imageUrl': driveUrl},
  ],
  'questions': [
    {
      'question': 'Question $revision',
      'imageUrl': driveUrl,
      'options': [
        {'text': 'Answer $revision'},
        {'imageUrl': driveUrl},
        {'text': 'Third'},
      ],
      'correctIndex': revision % 3,
    },
  ],
};

void main() {
  test(
    'same lesson and Drive URL refresh title, quiz, media and offline cache',
    () async {
      final root = await Directory.systemTemp.createTemp('anzen-refresh-');
      addTearDown(() => root.delete(recursive: true));
      var revision = 1;
      var offline = false;
      var imageCalls = 0;
      var detailCalls = 0;
      final client = MockClient((request) async {
        if (offline) throw const SocketException('offline');
        final path = request.url.path;
        final data = lesson(revision);
        if (path == '/api/learning/lessons') {
          return http.Response(jsonEncode([data]), 200);
        }
        if (path == '/api/learning/lessons/$lessonId') {
          detailCalls++;
          return http.Response(jsonEncode(data), 200);
        }
        if (path == '/api/learning/lessons/$lessonId/drive-images/$driveId') {
          expect(request.headers['authorization'], 'Bearer phase-4-token');
          imageCalls++;
          return http.Response.bytes([revision, revision, revision], 200);
        }
        fail('Unexpected request: ${request.url}');
      });
      final repository = LearningRepository(
        auth: authenticatedUser(),
        api: ApiClient(client: client),
        documentsDirectory: () async => root,
      );
      final original = (await repository.load()).single;
      expect(original.item.title, 'Lesson 1');
      expect(imageCalls, 3);
      await repository.load();
      expect(detailCalls, 1, reason: 'Unchanged lessons reuse cached details');
      expect(imageCalls, 3, reason: 'Unchanged media is not downloaded again');

      revision = 2;
      final updated = (await repository.load()).single;
      expect(updated.item.title, 'Lesson 2');
      expect(updated.item.description, 'Description 2');
      expect(updated.questions.single.question, 'Question 2');
      expect(updated.questions.single.options.first.text, 'Answer 2');
      expect(updated.questions.single.correctIndex, 2);
      expect(updated.item.progress, .5);
      expect(
        updated.cards.single.imagePath,
        isNot(original.cards.single.imagePath),
      );
      for (final path in [
        updated.cards.single.imagePath,
        updated.questions.single.imagePath,
        updated.questions.single.options[1].imagePath,
      ]) {
        expect(await File(path!).readAsBytes(), [2, 2, 2]);
      }
      expect(imageCalls, 6);

      // The user opens an existing card without leaving/reloading the library.
      revision = 3;
      final opened = (await repository.loadLesson(lessonId))!;
      expect(opened.item.title, 'Lesson 3');
      expect(opened.questions.single.question, 'Question 3');
      expect(await File(opened.cards.single.imagePath!).readAsBytes(), [
        3,
        3,
        3,
      ]);
      offline = true;
      final cached = (await repository.load()).single;
      expect(cached.updatedAt, opened.updatedAt);
      expect(cached.item.title, 'Lesson 3');
      expect(
        (await repository.loadLesson(lessonId))!.questions.single.question,
        'Question 3',
      );
      expect(await File(cached.cards.single.imagePath!).readAsBytes(), [
        3,
        3,
        3,
      ]);
    },
  );

  test(
    'content fingerprint refreshes edited content even when updatedAt is unchanged',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'anzen-content-version-',
      );
      addTearDown(() => root.delete(recursive: true));
      var revision = 1;
      final repository = LearningRepository(
        auth: authenticatedUser(),
        documentsDirectory: () async => root,
        api: ApiClient(
          client: MockClient((request) async {
            final data = lesson(revision);
            if (request.url.path == '/api/learning/lessons') {
              return http.Response(jsonEncode([data]), 200);
            }
            if (request.url.path == '/api/learning/lessons/$lessonId') {
              return http.Response(jsonEncode(data), 200);
            }
            return http.Response.bytes([revision], 200);
          }),
        ),
      );

      expect((await repository.load()).single.item.title, 'Lesson 1');
      revision = 2;
      final refreshed = (await repository.load()).single;
      expect(refreshed.item.title, 'Lesson 2');
      expect(refreshed.questions.single.question, 'Question 2');
    },
  );

  test(
    'failed detail refresh keeps old revision and retries next refresh',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'anzen-refresh-retry-',
      );
      addTearDown(() => root.delete(recursive: true));
      var revision = 1;
      var detailFails = false;
      final repository = LearningRepository(
        auth: authenticatedUser(),
        documentsDirectory: () async => root,
        api: ApiClient(
          client: MockClient((request) async {
            if (request.url.path == '/api/learning/lessons') {
              return http.Response(jsonEncode([lesson(revision)]), 200);
            }
            if (request.url.path == '/api/learning/lessons/$lessonId') {
              if (detailFails) {
                return http.Response('{"message":"Unavailable"}', 503);
              }
              return http.Response(jsonEncode(lesson(revision)), 200);
            }
            return http.Response.bytes([revision], 200);
          }),
        ),
      );
      final original = (await repository.load()).single;
      revision = 2;
      detailFails = true;
      final stale = (await repository.load()).single;
      expect(stale.updatedAt, original.updatedAt);
      expect(stale.questions.single.question, 'Question 1');
      detailFails = false;
      final retried = (await repository.load()).single;
      expect(retried.updatedAt, lesson(2)['updatedAt']);
      expect(retried.questions.single.question, 'Question 2');
    },
  );

  test(
    'opening removed or locked lessons never falls back to unlocked cache',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'anzen-refresh-access-',
      );
      addTearDown(() => root.delete(recursive: true));
      var status = 200;
      final repository = LearningRepository(
        auth: authenticatedUser(),
        documentsDirectory: () async => root,
        api: ApiClient(
          client: MockClient((request) async {
            if (request.url.path.contains('drive-images')) {
              return http.Response.bytes([1], 200);
            }
            return http.Response(
              jsonEncode(
                status == 200 ? lesson(1) : {'message': 'Not available'},
              ),
              status,
            );
          }),
        ),
      );
      expect(await repository.loadLesson(lessonId), isNotNull);
      for (final code in [403, 404]) {
        status = code;
        await expectLater(
          repository.loadLesson(lessonId),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );
}
