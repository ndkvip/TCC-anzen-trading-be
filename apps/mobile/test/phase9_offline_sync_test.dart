import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttc_ict_mobile/core/network/api_client.dart';
import 'package:ttc_ict_mobile/core/sync/offline_sync.dart';
import 'package:ttc_ict_mobile/features/auth/auth_controller.dart';
import 'package:ttc_ict_mobile/features/auth/auth_models.dart';
import 'package:ttc_ict_mobile/features/learning/learning_repository.dart';
import 'package:ttc_ict_mobile/features/journal/journal_models.dart';
import 'package:ttc_ict_mobile/features/journal/journal_repository.dart';
import 'package:ttc_ict_mobile/features/personal/checkin_repository.dart';
import 'package:ttc_ict_mobile/features/personal/personal_models.dart';
import 'package:ttc_ict_mobile/features/plan/plan_document.dart';
import 'package:ttc_ict_mobile/features/plan/plan_local_repository.dart';

AuthController _auth(String id) => AuthController()
  ..accessToken = 'phase-9-token'
  ..user = AppUser.fromJson({'id': id, 'role': 'STUDENT'});

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('sync queue survives restart and removes an item after retry', () async {
    final root = await Directory.systemTemp.createTemp('anzen-phase9-queue-');
    addTearDown(() => root.delete(recursive: true));
    OfflineSyncQueue queue() => OfflineSyncQueue(
      accountId: 'account-a',
      documentsDirectory: () async => root,
    );

    await queue().enqueue(
      key: 'lesson-1',
      type: 'learning_progress',
      payload: {'lessonId': 'lesson-1', 'progress': .5},
    );
    await queue().markFailed('lesson-1', const SocketException('offline'));

    final restarted = queue();
    final failed = await restarted.load();
    expect(failed.single.state, OfflineSyncState.failed);
    expect(failed.single.retryCount, 1);
    expect((await restarted.snapshot()).failedCount, 1);

    await restarted.markSyncing('lesson-1');
    await restarted.markSynced('lesson-1');
    expect(await queue().load(), isEmpty);
  });

  test(
    'sync queue serializes separate instances for the same account',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'anzen-phase9-queue-race-',
      );
      addTearDown(() => root.delete(recursive: true));
      OfflineSyncQueue queue(String account) => OfflineSyncQueue(
        accountId: account,
        documentsDirectory: () async => root,
      );

      await Future.wait([
        queue(
          'account-race',
        ).enqueue(key: 'plan-1', type: 'plan', payload: {'value': 1}),
        queue(
          'account-race',
        ).enqueue(key: 'plan-2', type: 'plan', payload: {'value': 2}),
      ]);

      expect(
        (await queue('account-race').load()).map((item) => item.key),
        containsAll(<String>['plan-1', 'plan-2']),
      );
    },
  );

  test(
    'sync queue reports corrupt JSON instead of treating it as empty',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'anzen-phase9-queue-corrupt-',
      );
      addTearDown(() => root.delete(recursive: true));
      final syncDirectory = Directory('${root.path}/sync')
        ..createSync(recursive: true);
      final file = File('${syncDirectory.path}/queue_account-corrupt.json');
      await file.writeAsString('{not-json');
      final queue = OfflineSyncQueue(
        accountId: 'account-corrupt',
        documentsDirectory: () async => root,
      );

      await expectLater(
        queue.load(),
        throwsA(isA<OfflineSyncQueueCorruptionException>()),
      );
      expect((await queue.snapshot()).state, OfflineSyncState.failed);
      expect(await file.readAsString(), '{not-json');
    },
  );

  test(
    'check-in persists offline and retries after a new repository',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'anzen-phase9-checkin-',
      );
      addTearDown(() => root.delete(recursive: true));
      final auth = _auth('checkin-account');
      var online = false;
      final api = ApiClient(
        client: MockClient((request) async {
          if (!online) throw const SocketException('offline');
          if (request.method == 'PUT') return _json({'date': '2026-10-14'});
          return _json({'data': []});
        }),
      );
      final first = CheckinRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      final entry = CheckinEntry(
        date: DateTime(2026, 10, 14),
        scores: [4, 3, 4, 3, 4],
      );

      await first.saveEntry(entry, [entry]);
      expect(first.pendingCount, 1);
      expect((await first.load()).single.scores, entry.scores);

      online = true;
      final restarted = CheckinRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      final history = await restarted.load();
      expect(history.single.scores, entry.scores);
      expect(restarted.pendingCount, 0);
      expect(restarted.syncState, OfflineSyncState.synced);
    },
  );

  test(
    'corrupt queue remains visible without breaking cached screens',
    () async {
      final root = await Directory.systemTemp.createTemp('anzen-queue-ui-');
      addTearDown(() => root.delete(recursive: true));
      final auth = _auth('corrupt-account');
      var requests = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          requests++;
          throw const SocketException('offline');
        }),
      );
      final entry = CheckinEntry(
        date: DateTime(2026, 10, 14),
        scores: [4, 3, 2, 1, 0],
      );
      final checkin = CheckinRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      await checkin.saveEntry(entry, [entry]);
      final file = File('${root.path}/sync/queue_corrupt-account.json');
      await file.writeAsString('{broken');
      requests = 0;

      expect((await checkin.load()).single.scores, entry.scores);
      expect(await checkin.syncPending(), 0);
      await checkin.saveEntry(entry, [entry]);
      expect(checkin.syncState, OfflineSyncState.failed);
      expect(checkin.lastSyncError, contains('giữ nguyên'));

      final learning = LearningRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      expect(await learning.syncPendingProgress(), 0);
      await learning.saveProgress('lesson-1', .5);
      expect(learning.syncState, OfflineSyncState.failed);
      expect(learning.lastSyncError, isNotEmpty);

      final plan = PlanLocalRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      expect(
        (await plan.loadFor(scope: 'Ngày', date: entry.date)).syncState,
        PlanSyncState.failed,
      );
      expect(await plan.syncPending(), 0);
      expect(await plan.list(), isEmpty);
      expect(await file.readAsString(), '{broken');
      expect(requests, 0);
    },
  );

  test('check-in retry after response loss upserts the same day', () async {
    final root = await Directory.systemTemp.createTemp('anzen-checkin-lost-');
    addTearDown(() => root.delete(recursive: true));
    final rows = <String, Map<String, dynamic>>{};
    var writes = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          rows[body['date'] as String] = {
            'checkinDate': body['date'],
            'scores': body['scores'],
          };
          writes++;
          if (writes == 1) throw const SocketException('response lost');
          return _json(rows.values.single);
        }
        return _json({'data': rows.values.toList()});
      }),
    );
    CheckinRepository repository() => CheckinRepository(
      auth: _auth('checkin-lost'),
      api: api,
      documentsDirectory: () async => root,
    );
    final entry = CheckinEntry(
      date: DateTime(2026, 10, 14),
      scores: [4, 4, 3, 3, 2],
    );
    final first = repository();
    await first.saveEntry(entry, [entry]);
    expect(first.syncState, OfflineSyncState.failed);
    final restarted = repository();
    expect((await restarted.load()).single.scores, entry.scores);
    expect(rows, hasLength(1));
    expect(writes, 2);
    expect(restarted.pendingCount, 0);
  });

  for (final journal in [false, true]) {
    test(
      '${journal ? 'journal' : 'plan'} media retry keeps its local reference after response loss',
      () async {
        final root = await Directory.systemTemp.createTemp('anzen-media-lost-');
        addTearDown(() => root.delete(recursive: true));
        final image = File('${root.path}/chart.png');
        await image.writeAsBytes([1, 2, 3]);
        final auth = _auth('media-account');
        var uploads = 0;
        Map<String, dynamic>? saved;
        const url = 'https://drive.google.com/uc?id=drive-chart';
        final api = ApiClient(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/media/upload')) {
              expect(request.body, contains(image.path));
              expect(request.body, contains(journal ? 'JOURNAL' : 'PLAN'));
              uploads++;
              if (uploads == 1) {
                throw const SocketException('upload response lost');
              }
              return _json({'remoteUrl': url});
            }
            if (request.url.path.contains('drive-images')) {
              expect(request.headers['authorization'], 'Bearer phase-9-token');
              return http.Response.bytes([1, 2, 3], 200);
            }
            if (request.method == 'POST' || request.method == 'PUT') {
              saved = Map<String, dynamic>.from(jsonDecode(request.body) as Map)
                ..putIfAbsent('id', () => 'remote-plan-id');
              return _json(saved!);
            }
            return _json({
              'data': saved == null ? [] : [saved],
            });
          }),
        );
        if (journal) {
          JournalRepository repository() => JournalRepository(
            auth: auth,
            api: api,
            documentsDirectory: () async => root,
          );
          final first = repository();
          await first.create(
            TradeEntry(
              symbol: 'BTCUSDT',
              direction: 'Long',
              pnl: 2,
              r: 1,
              setup: 'AMD',
              management: 'Set and forget',
              imageUrls: [image.path],
            ),
            mode: 'INTRA_DAY',
            date: '2026-10-14',
          );
          expect(first.pendingCount, 1);
          final restarted = repository();
          await restarted.load();
          expect(restarted.pendingCount, 0);
          expect(saved?['processImageUrls'], [url]);
        } else {
          PlanLocalRepository repository() => PlanLocalRepository(
            auth: auth,
            api: api,
            documentsDirectory: () async => root,
          );
          final document =
              PlanDocument.emptyFor(scope: 'Ngày', date: DateTime(2026, 10, 14))
                ..status = PlanStatus.completed
                ..contentDelta = [
                  {
                    'insert': {'image': image.path},
                  },
                  {'insert': '\n'},
                ];
          await repository().save(document);
          expect(document.syncState, PlanSyncState.failed);
          final restarted = repository();
          expect(await restarted.syncPending(), 1);
          final stored = await restarted.load();
          expect(stored.id, 'remote-plan-id');
          expect(stored.status, PlanStatus.completed);
          expect(stored.syncState, PlanSyncState.synced);
          expect(saved?['imageUrls'], [url]);
        }
        expect(uploads, 2);
      },
    );
  }

  test(
    'learning progress remains queued offline and syncs after restart',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'anzen-phase9-progress-',
      );
      addTearDown(() => root.delete(recursive: true));
      final auth = _auth('learning-account');
      var online = false;
      final api = ApiClient(
        client: MockClient((request) async {
          if (!online) throw const SocketException('offline');
          return _json({
            'id': 'remote-plan-id',
            'scope': 'DAY',
            'periodKey': '2026-10-14',
            'contentDelta': [
              {'insert': 'Server copy\n'},
            ],
          });
        }),
      );
      final first = LearningRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );

      await first.saveProgress(
        'lesson-1',
        .75,
        answeredCount: 3,
        correctCount: 2,
      );
      expect(first.pendingProgressCount, 1);

      online = true;
      final restarted = LearningRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      expect(await restarted.syncPendingProgress(), 1);
      expect(restarted.pendingProgressCount, 0);
      expect(restarted.syncState, OfflineSyncState.synced);
    },
  );

  test(
    'offline plan delete is retried without resurrecting the local copy',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'anzen-phase9-plan-delete-',
      );
      addTearDown(() => root.delete(recursive: true));
      final auth = _auth('plan-delete-account');
      var online = false;
      var deleteCalls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (!online) throw const SocketException('offline');
          if (request.method == 'DELETE') {
            deleteCalls++;
            return _json({});
          }
          return _json({});
        }),
      );
      final document = PlanDocument(
        id: 'remote-plan-id',
        title: 'Kế hoạch đã lưu',
        date: DateTime(2026, 10, 14),
        scope: 'Ngày',
        session: 'London session',
        blocks: [PlanBlock.text('Nội dung cần xóa')],
      );
      final first = PlanLocalRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      await first.save(document);
      await first.delete(document);
      expect(
        (await first.loadFor(scope: 'Ngày', date: DateTime(2026, 10, 14))).id,
        isNot('remote-plan-id'),
      );

      online = true;
      final restarted = PlanLocalRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      await restarted.syncPending();
      expect(deleteCalls, 1);
      expect(
        (await restarted.loadFor(
          scope: 'Ngày',
          date: DateTime(2026, 10, 14),
        )).id,
        isNot('remote-plan-id'),
      );
    },
  );

  test(
    'deleting a draft after a lost PUT response removes the acknowledged remote plan',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'anzen-phase9-plan-lost-put-delete-',
      );
      addTearDown(() => root.delete(recursive: true));
      final auth = _auth('plan-lost-put-delete-account');
      var putCalls = 0;
      var resolveCalls = 0;
      var deleteCalls = 0;
      var remoteExists = false;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            putCalls++;
            remoteExists = true;
            if (putCalls == 1) {
              throw const SocketException('response lost after server commit');
            }
            return _json({
              'id': 'remote-plan-id',
              'scope': 'DAY',
              'periodKey': '2026-10-14',
              'title': 'Plan đã lưu',
              'contentDelta': [
                {'insert': 'Nội dung\n'},
              ],
              'timeframePairs': <String>[],
              'status': 'DRAFT',
            });
          }
          if (request.url.path.endsWith('/plans/resolve')) {
            resolveCalls++;
            if (!remoteExists) return _json({});
            return _json({
              'id': 'remote-plan-id',
              'scope': 'DAY',
              'periodKey': '2026-10-14',
              'title': 'Plan đã lưu',
              'contentDelta': [
                {'insert': 'Nội dung\n'},
              ],
              'timeframePairs': <String>[],
              'status': 'DRAFT',
            });
          }
          if (request.method == 'DELETE') {
            deleteCalls++;
            remoteExists = false;
            expect(request.url.path, endsWith('/plans/remote-plan-id'));
            return _json({});
          }
          return _json({'data': []});
        }),
      );
      final repository = PlanLocalRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      final document = PlanDocument.emptyFor(
        scope: 'Ngày',
        date: DateTime(2026, 10, 14),
      )..title = 'Plan đã lưu';

      await repository.save(document);
      expect(document.syncState, PlanSyncState.failed);
      expect(document.id, startsWith('plan-'));

      await repository.delete(document);

      expect(putCalls, 1);
      expect(resolveCalls, 1);
      expect(deleteCalls, 1);
      expect(await repository.syncPending(), 0);
      expect(
        (await repository.loadFor(
          scope: 'Ngày',
          date: DateTime(2026, 10, 14),
        )).id,
        isNot('remote-plan-id'),
      );
    },
  );

  test('plan failed state and content survive restart', () async {
    final root = await Directory.systemTemp.createTemp('anzen-phase9-plan-');
    addTearDown(() => root.delete(recursive: true));
    final auth = _auth('plan-account');
    final api = ApiClient(
      client: MockClient((_) async => throw const SocketException('offline')),
    );
    final document =
        PlanDocument.emptyFor(scope: 'Ngày', date: DateTime(2026, 10, 14))
          ..contentDelta = [
            {'insert': 'Kế hoạch được giữ lại sau khi mất mạng\n'},
          ];
    final first = PlanLocalRepository(
      auth: auth,
      api: api,
      documentsDirectory: () async => root,
    );

    await first.save(document);

    final restarted = PlanLocalRepository(
      auth: auth,
      api: api,
      documentsDirectory: () async => root,
    );
    final loaded = await restarted.loadFor(
      scope: 'Ngày',
      date: DateTime(2026, 10, 14),
    );
    expect(loaded.contentDelta.toString(), contains('được giữ lại'));
    expect(loaded.syncState, PlanSyncState.failed);
    expect(loaded.syncRetryCount, greaterThanOrEqualTo(1));
  });

  test('plan mutations from concurrent callers are serialized', () async {
    final root = await Directory.systemTemp.createTemp(
      'anzen-phase9-plan-race-',
    );
    addTearDown(() => root.delete(recursive: true));
    final auth = _auth('plan-race-account');
    final api = ApiClient(
      client: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return _json({
          'id': request.url.queryParameters['id'] ?? 'remote-plan',
          'scope': 'DAY',
          'periodKey': request.body.contains('2026-10-15')
              ? '2026-10-15'
              : '2026-10-14',
          'title': 'Plan',
          'contentDelta': [
            {'insert': '\n'},
          ],
          'timeframePairs': <String>[],
          'status': 'DRAFT',
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }),
    );
    final repository = PlanLocalRepository(
      auth: auth,
      api: api,
      documentsDirectory: () async => root,
    );
    final first = PlanDocument.emptyFor(
      scope: 'Ngày',
      date: DateTime(2026, 10, 14),
    )..title = 'Ngày 14';
    final second = PlanDocument.emptyFor(
      scope: 'Ngày',
      date: DateTime(2026, 10, 15),
    )..title = 'Ngày 15';

    await Future.wait([repository.save(first), repository.save(second)]);
    final values = await repository.list();
    expect(
      values.map((value) => value.title),
      containsAll(<String>['Ngày 14', 'Ngày 15']),
    );
  });
}
