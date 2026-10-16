import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/features/auth/auth_controller.dart';
import 'package:ttc_ict_mobile/features/journal/journal_models.dart';
import 'package:ttc_ict_mobile/features/journal/journal_repository.dart';
import 'package:ttc_ict_mobile/features/learning/learning_progress_local_repository.dart';
import 'package:ttc_ict_mobile/features/plan/plan_document.dart';
import 'package:ttc_ict_mobile/features/plan/plan_local_repository.dart';

void main() {
  group('Phase 3 local-first repositories', () {
    test('learning progress is monotonic and isolated by account', () async {
      final root = await Directory.systemTemp.createTemp('anzen-learning-');
      addTearDown(() => root.delete(recursive: true));
      final a = LearningProgressLocalRepository(
        documentsDirectory: () async => root,
        accountId: 'account-a',
      );
      final b = LearningProgressLocalRepository(
        documentsDirectory: () async => root,
        accountId: 'account-b',
      );

      await a.save('lesson-1', .7);
      await a.save('lesson-1', .2);

      expect((await a.load())['lesson-1'], .7);
      expect(await b.load(), isEmpty);
    });

    test('journal featured trade is the highest RR closed trade', () {
      const running = TradeEntry(
        id: 'running',
        symbol: 'BTCUSDT',
        direction: 'Long',
        pnl: null,
        r: 99,
        setup: 'AMD',
        management: 'Set and forget',
      );
      const lower = TradeEntry(
        id: 'lower',
        symbol: 'XAUUSD',
        direction: 'Short',
        pnl: 40,
        r: 1.5,
        setup: 'MMXM',
        management: 'Xử lý lệnh',
      );
      const highest = TradeEntry(
        id: 'highest',
        symbol: 'ETHUSDT',
        direction: 'Long',
        pnl: -10,
        r: 3.2,
        setup: 'AMD',
        management: 'Xử lý lệnh',
      );

      expect(highestClosedRRTrade([running, lower, highest])?.id, highest.id);
      expect(highestClosedRRTrade([running]), isNull);
    });

    test('journal persists running and closed trades offline', () async {
      final root = await Directory.systemTemp.createTemp('anzen-journal-');
      addTearDown(() => root.delete(recursive: true));
      final repository = JournalRepository(
        auth: AuthController(),
        documentsDirectory: () async => root,
      );

      await repository.create(
        const TradeEntry(
          symbol: 'BTCUSDT',
          direction: 'Long',
          pnl: null,
          r: 0,
          setup: 'AMD',
          management: 'Set and forget',
          timeframePair: 'H1-M5',
        ),
        mode: 'INTRA_DAY',
        date: '2026-09-02',
      );
      await repository.create(
        const TradeEntry(
          symbol: 'XAUUSD',
          direction: 'Short',
          pnl: 125,
          r: 2.5,
          setup: 'MMXM',
          management: 'Xử lý lệnh',
        ),
        mode: 'SWING',
      );

      final values = await repository.load();
      expect(values, hasLength(2));
      expect(values.first.isRunning, isTrue);
      expect(values.first.tradeDate, '2026-09-02');
      expect(values.first.timeframePair, 'H1-M5');
      expect(values.last.mode, 'SWING');
      expect(values.last.pnl, 125);
    });

    test('journal edits and deletes survive offline restart', () async {
      final root = await Directory.systemTemp.createTemp('anzen-journal-edit-');
      addTearDown(() => root.delete(recursive: true));
      final auth = AuthController();
      final repository = JournalRepository(
        auth: auth,
        documentsDirectory: () async => root,
      );
      final created = await repository.create(
        const TradeEntry(
          symbol: 'BTCUSDT',
          direction: 'Long',
          pnl: null,
          r: 0,
          setup: 'AMD',
          management: 'Set and forget',
        ),
        mode: 'INTRA_DAY',
        date: '2026-09-02',
      );
      final updated = await repository.update(
        TradeEntry(
          id: created.id,
          symbol: created.symbol,
          direction: created.direction,
          pnl: 90,
          r: 1.8,
          setup: created.setup,
          management: created.management,
          tradeDate: created.tradeDate,
          mode: created.mode,
        ),
      );
      expect(updated.pnl, 90);

      final restarted = JournalRepository(
        auth: AuthController(),
        documentsDirectory: () async => root,
      );
      expect((await restarted.load()).single.pnl, 90);
      await restarted.deleteEntry((await restarted.load()).single);
      expect(await restarted.load(), isEmpty);
    });

    test('plan documents are isolated by account and period', () async {
      final root = await Directory.systemTemp.createTemp('anzen-plans-');
      addTearDown(() => root.delete(recursive: true));
      final accountA = PlanLocalRepository(
        documentsDirectory: () async => root,
        accountId: 'account-a',
      );
      final accountB = PlanLocalRepository(
        documentsDirectory: () async => root,
        accountId: 'account-b',
      );
      final day =
          PlanDocument.emptyFor(scope: 'Ngày', date: DateTime(2026, 9, 2))
            ..contentDelta = [
              {'insert': 'Kế hoạch riêng của A\n'},
            ];
      await accountA.save(day);

      expect(
        (await accountA.loadFor(
          scope: 'Ngày',
          date: DateTime(2026, 9, 2),
        )).contentDelta.toString(),
        contains('riêng của A'),
      );
      expect(
        (await accountB.loadFor(
          scope: 'Ngày',
          date: DateTime(2026, 9, 2),
        )).contentDelta.toString(),
        isNot(contains('riêng của A')),
      );
    });

    test('plan day, week and month map to separate offline files', () async {
      final root = await Directory.systemTemp.createTemp('anzen-periods-');
      addTearDown(() => root.delete(recursive: true));
      final repository = PlanLocalRepository(
        documentsDirectory: () async => root,
        accountId: 'account',
      );
      for (final scope in ['Ngày', 'Tuần', 'Tháng']) {
        final document =
            PlanDocument.emptyFor(scope: scope, date: DateTime(2026, 9, 2))
              ..contentDelta = [
                {'insert': '$scope content\n'},
              ];
        await repository.save(document);
      }

      for (final scope in ['Ngày', 'Tuần', 'Tháng']) {
        final loaded = await repository.loadFor(
          scope: scope,
          date: DateTime(2026, 9, 2),
        );
        expect(loaded.contentDelta.toString(), contains('$scope content'));
      }
    });
  });
}
