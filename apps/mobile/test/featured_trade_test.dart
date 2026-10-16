import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttc_ict_mobile/core/network/api_client.dart';
import 'package:ttc_ict_mobile/core/theme/app_theme.dart';
import 'package:ttc_ict_mobile/features/home/featured_trade_repository.dart';
import 'package:ttc_ict_mobile/features/home/featured_trade_widgets.dart';
import 'package:ttc_ict_mobile/features/journal/journal_models.dart';

FeaturedTrade article(String id) => FeaturedTrade(
  id: id,
  weekStart: '2026-10-05',
  title: 'Giao dịch $id',
  summary: null,
  coverImageUrl: null,
  isActive: true,
  contentBlocks: [FeaturedTradeBlock(type: 'text', text: 'Nội dung $id')],
);

void main() {
  test(
    'featured Drive images use the image endpoint instead of HTML download pages',
    () {
      final trade = FeaturedTrade.fromJson({
        'id': 'drive',
        'contentBlocks': [
          {
            'type': 'image',
            'imageUrl':
                'https://drive.google.com/uc?export=download&id=drive-file-123',
          },
        ],
      });
      expect(
        trade.imageUrls.single,
        '${ApiClient.baseUrl}/featured-trades/drive-images/drive-file-123',
      );
    },
  );
  test(
    'repository loads articles, keeps last success offline and clears on empty response',
    () async {
      var offline = false;
      var rows = <Map<String, dynamic>>[
        {
          'id': '1',
          'title': 'BTC',
          'isActive': true,
          'contentBlocks': [
            {'type': 'text', 'text': 'A'},
            {'type': 'image', 'imageUrl': '/chart.webp'},
            {'type': 'text', 'text': 'B'},
          ],
        },
        {
          'id': '2',
          'title': 'Gold',
          'isActive': false,
          'contentBlocks': [
            {'type': 'text', 'text': 'Hidden'},
          ],
        },
      ];
      final repository = FeaturedTradeRepository(
        api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.queryParameters['week'], '2026-10-05');
            if (offline) throw const SocketException('offline');
            return http.Response(jsonEncode(rows), 200);
          }),
        ),
      );
      final result = await repository.load(DateTime(2026, 10, 8));
      expect(result.single.title, 'BTC');
      expect(result.single.contentBlocks.map((block) => block.type), [
        'text',
        'image',
        'text',
      ]);
      offline = true;
      expect(await repository.load(DateTime(2026, 10, 8)), hasLength(1));
      offline = false;
      rows = [];
      expect(await repository.load(DateTime(2026, 10, 8)), isEmpty);
    },
  );

  test('legacy singleton remains readable', () async {
    final repository = FeaturedTradeRepository(
      api: ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'id': 'old',
              'imageUrls': ['/old.webp'],
            }),
            200,
          ),
        ),
      ),
    );
    expect((await repository.load(DateTime(2026, 10, 8))).single.imageUrls, [
      '${ApiClient.baseUrl}/old.webp',
    ]);
  });

  testWidgets(
    'carousel restarts when articles arrive, opens correct detail and stops while reading',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget host(List<FeaturedTrade> trades) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: FeaturedTradeHomeSection(trades: trades)),
      );
      await tester.pumpWidget(host([article('1')]));
      await tester.pumpWidget(host([article('1'), article('2')]));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      expect(controller.page, closeTo(1, .01));
      await tester.tap(find.text('Giao dịch 2'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết giao dịch'), findsOneWidget);
      expect(find.text('Nội dung 2'), findsOneWidget);
      expect(find.text('Nội dung 1'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      expect(controller.page, closeTo(1, .01));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pumpWidget(host([article('1')]));
      await tester.pumpAndSettle();
      expect(controller.page, closeTo(0, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
