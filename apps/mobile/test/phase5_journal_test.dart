import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttc_ict_mobile/core/network/api_client.dart';
import 'package:ttc_ict_mobile/features/auth/auth_controller.dart';
import 'package:ttc_ict_mobile/features/auth/auth_models.dart';
import 'package:ttc_ict_mobile/features/journal/journal_filter.dart';
import 'package:ttc_ict_mobile/features/journal/journal_models.dart';
import 'package:ttc_ict_mobile/features/journal/journal_repository.dart';

AuthController _auth() => AuthController()
  ..accessToken = 'test-token'
  ..user = AppUser.fromJson({'id': 'account-a', 'role': 'STUDENT'});

const _entry = TradeEntry(
  symbol: 'BTCUSDT',
  direction: 'Long',
  pnl: null,
  r: 0,
  setup: 'AMD',
  management: 'Set and forget',
);

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  const running = TradeEntry(
    symbol: 'BTCUSDT',
    direction: 'Long',
    pnl: null,
    r: 0,
    setup: 'AMD',
    management: 'Set and forget',
  );
  const closed = TradeEntry(
    symbol: 'XAUUSD',
    direction: 'Short',
    pnl: 10,
    r: 2,
    setup: 'MMXM',
    management: 'Xử lý lệnh',
  );

  test('journal filters split running, closed, asset and management', () {
    final filter = JournalFilter();
    expect(filter.apply([running, closed]), hasLength(2));
    filter.status = JournalStatus.running;
    expect(filter.apply([running, closed]), [running]);
    filter.status = JournalStatus.all;
    filter.symbol = 'XAUUSD';
    filter.management = 'Xử lý lệnh';
    expect(filter.apply([running, closed]), [closed]);
  });

  test('Swing strategy groups by timeframe and setup, ranked by PNL', () {
    const lower = TradeEntry(
      symbol: 'BTCUSDT',
      direction: 'Long',
      pnl: 90,
      r: 4,
      setup: 'AMD',
      management: 'Xử lý lệnh',
      timeframePair: 'H4-M15',
    );
    const best = TradeEntry(
      symbol: 'XAUUSD',
      direction: 'Short',
      pnl: 120,
      r: 2,
      setup: 'AMD',
      management: 'Set and forget',
      timeframePair: 'D1-H1',
    );
    const running = TradeEntry(
      symbol: 'ETHUSDT',
      direction: 'Long',
      pnl: null,
      r: 99,
      setup: 'MMXM',
      management: 'Set and forget',
      timeframePair: 'D1-H1',
    );

    final summary = bestSwingStrategy([lower, best, running]);
    expect(summary?.label, 'D1-H1 · AMD');
    expect(summary?.pnl, 120);
    expect(summary?.totalR, 2);
    expect(summary?.tradeCount, 1);
  });

  test('journal note image embeds are extracted for Drive upload', () {
    final delta = [
      {'insert': 'Bối cảnh\n'},
      {
        'insert': {'image': '/tmp/chart.png'},
      },
      {'insert': '\n'},
    ];
    expect(journalNoteImages(delta), ['/tmp/chart.png']);
    expect(
      replaceJournalNoteImages(delta, {
        '/tmp/chart.png': 'https://drive/chart',
      }).any(
        (item) =>
            item['insert'] is Map &&
            (item['insert'] as Map)['image'] == 'https://drive/chart',
      ),
      isTrue,
    );
  });

  test(
    'acknowledged create uses POST response without redundant PATCH',
    () async {
      final root = await Directory.systemTemp.createTemp('anzen-p5-create-');
      addTearDown(() => root.delete(recursive: true));
      final methods = <String>[];
      final repository = JournalRepository(
        auth: _auth(),
        documentsDirectory: () async => root,
        api: ApiClient(
          client: MockClient((request) async {
            methods.add(request.method);
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            body['riskReward'] =
                0; // JSONB and number normalization is harmless.
            return _json(body, 201);
          }),
        ),
      );
      final created = await repository.create(
        _entry,
        mode: 'INTRA_DAY',
        date: '2026-10-12',
      );
      expect(created.id, isNotNull);
      expect(methods, ['POST']);
      expect(repository.pendingCount, 0);
    },
  );

  test(
    'lost create response plus offline edits reconcile without duplicates',
    () async {
      final root = await Directory.systemTemp.createTemp('anzen-p5-retry-');
      addTearDown(() => root.delete(recursive: true));
      final auth = _auth();
      var online = true;
      var loseResponse = true;
      Map<String, dynamic>? remote;
      var patches = 0;
      var inserts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (!online) throw const SocketException('offline');
          if (request.method == 'POST') {
            if (remote == null) {
              remote = jsonDecode(request.body);
              inserts++;
            }
            if (loseResponse) {
              loseResponse = false;
              throw const SocketException('response lost');
            }
            return _json(remote!);
          }
          if (request.method == 'PATCH') {
            patches++;
            remote = {
              ...remote!,
              ...jsonDecode(request.body) as Map<String, dynamic>,
            };
            return _json(remote!);
          }
          return _json(
            request.url.queryParameters['mode'] == 'INTRA_DAY' ? [remote!] : [],
          );
        }),
      );
      final repository = JournalRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      final created = await repository.create(
        _entry,
        mode: 'INTRA_DAY',
        date: '2026-10-12',
      );
      expect(repository.pendingCount, 1);
      online = false;
      await repository.update(
        TradeEntry.fromJson(created.toJson()..['pnl'] = 120),
      );
      online = true;
      final restarted = JournalRepository(
        auth: auth,
        api: api,
        documentsDirectory: () async => root,
      );
      final entries = await restarted.load();
      expect(entries.single.pnl, 120);
      expect(remote!['pnl'], 120);
      expect(inserts, 1);
      expect(patches, 1);
      expect(restarted.pendingCount, 0);
    },
  );

  test('remote inline images are cached and retained when offline', () async {
    final root = await Directory.systemTemp.createTemp('anzen-p5-images-');
    addTearDown(() => root.delete(recursive: true));
    final auth = _auth();
    var online = true;
    const url = 'https://drive.google.com/uc?export=download&id=chart-file';
    final remote = _entry.toJson(date: '2026-10-12')
      ..['id'] = '96b1e151-cba3-4f47-a7f2-23146c352665'
      ..['processImageUrls'] = [url]
      ..['notesDelta'] = [
        {
          'insert': {'image': url},
        },
        {'insert': '\n'},
      ];
    final repository = JournalRepository(
      auth: auth,
      documentsDirectory: () async => root,
      api: ApiClient(
        client: MockClient((request) async {
          if (!online) throw const SocketException('offline');
          if (request.url.path.contains('drive-images')) {
            expect(
              request.url.path,
              endsWith('/media/drive-images/chart-file'),
            );
            return http.Response.bytes([1, 2, 3], 200);
          }
          return _json(
            request.url.queryParameters['mode'] == 'INTRA_DAY' ? [remote] : [],
          );
        }),
      ),
    );
    final first = (await repository.load()).single;
    final path = journalNoteImages(first.notesDelta).single;
    expect(await File(path).exists(), isTrue);
    expect(first.imageUrls, [path]);
    online = false;
    final restored = (await repository.load()).single;
    expect(journalNoteImages(restored.notesDelta), [path]);
    expect(await File(restored.imageUrls.single).readAsBytes(), [1, 2, 3]);
  });

  test(
    'corrupt offline cache is preserved instead of being overwritten',
    () async {
      final root = await Directory.systemTemp.createTemp('anzen-p5-cache-');
      addTearDown(() => root.delete(recursive: true));
      await Directory('${root.path}/journal').create();
      final file = File('${root.path}/journal/account-a.json');
      await file.writeAsString('{broken');
      final repository = JournalRepository(
        auth: _auth(),
        documentsDirectory: () async => root,
      );
      await expectLater(repository.load(), throwsA(isA<ApiException>()));
      expect(await file.readAsString(), '{broken');
    },
  );
}
