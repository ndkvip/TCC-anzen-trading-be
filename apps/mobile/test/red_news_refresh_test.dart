import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttc_ict_mobile/core/network/api_client.dart';
import 'package:ttc_ict_mobile/core/theme/app_theme.dart';
import 'package:ttc_ict_mobile/features/home/red_news_repository.dart';
import 'package:ttc_ict_mobile/features/home/red_news_widgets.dart';

void main() {
  test(
    'successful refresh time survives offline restart and empty news',
    () async {
      final directory = await Directory.systemTemp.createTemp('anzen-news-');
      addTearDown(() => directory.delete(recursive: true));
      var offline = false;
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/api/red-news');
          if (offline) throw const SocketException('offline');
          return http.Response('[]', 200);
        }),
      );
      final repository = RedNewsRepository(
        api: api,
        documentsDirectory: () async => directory,
      );
      expect(await repository.load(), isEmpty);
      expect(repository.lastLoadWasOnline, isTrue);
      final updated = repository.lastUpdated;
      expect(updated, isNotNull);

      offline = true;
      final reopened = RedNewsRepository(
        api: api,
        documentsDirectory: () async => directory,
      );
      expect(await reopened.load(), isEmpty);
      expect(reopened.lastLoadWasOnline, isFalse);
      expect(reopened.lastUpdated, updated);
      expect(await reopened.load(), isEmpty);
      expect(reopened.lastUpdated, updated);
    },
  );

  test('legacy cache loads without inventing a refresh timestamp', () async {
    final directory = await Directory.systemTemp.createTemp('anzen-news-old-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/red_news.json').writeAsString(
      jsonEncode([
        {'id': 'old-news', 'title': 'CPI', 'releaseAt': '2026-10-04T07:00:00Z'},
      ]),
    );
    final repository = RedNewsRepository(
      api: ApiClient(client: MockClient((_) async => http.Response('', 503))),
      documentsDirectory: () async => directory,
    );
    expect((await repository.load()).single.title, 'CPI');
    expect(repository.lastUpdated, isNull);
    expect(repository.lastLoadWasOnline, isFalse);
  });

  testWidgets(
    'compact refresh shows time, invokes action and disables while busy',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var calls = 0;
      Widget host({bool busy = false, DateTime? updated}) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: RedNewsSection(
              items: const [],
              now: DateTime(2026, 10, 4),
              lastUpdated: updated,
              isRefreshing: busy,
              onRefresh: () async => calls++,
            ),
          ),
        ),
      );

      await tester.pumpWidget(host(updated: DateTime(2026, 10, 4, 9, 5)));
      expect(find.text('Cập nhật 09:05'), findsOneWidget);
      expect(find.text('TỰ ĐỘNG CẬP NHẬT'), findsNothing);
      await tester.tap(find.byTooltip('Cập nhật tin quan trọng'));
      expect(calls, 1);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(host(busy: true));
      await tester.pump();
      expect(find.text('Chưa cập nhật'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
