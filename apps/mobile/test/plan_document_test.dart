import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/features/plan/plan_document.dart';
import 'package:ttc_ict_mobile/features/plan/plan_local_repository.dart';

void main() {
  test('plan document round trips ordered text and image blocks', () {
    final original = PlanDocument(
      id: 'plan-test',
      title: 'Kế hoạch XAUUSD',
      date: DateTime(2026, 8, 27),
      scope: 'Ngày',
      session: 'London',
      timeframePairs: ['H4-M15', 'H1-M5'],
      blocks: [
        PlanBlock.text('Bối cảnh', bold: true),
        PlanBlock.image('/local/plan-chart.jpg'),
        PlanBlock.text('Kịch bản', italic: true, alignment: TextAlign.center),
      ],
    );

    final decoded = PlanDocument.fromJson(original.toJson());

    expect(decoded.id, original.id);
    expect(decoded.title, original.title);
    expect(decoded.date, original.date);
    expect(decoded.timeframePairs, original.timeframePairs);
    expect(decoded.blocks.map((block) => block.type), [
      PlanBlockType.text,
      PlanBlockType.image,
      PlanBlockType.text,
    ]);
    expect(decoded.blocks[0].bold, isTrue);
    expect(decoded.blocks[1].content, '/local/plan-chart.jpg');
    expect(decoded.blocks[2].alignment, TextAlign.center);
  });

  test('empty remote content becomes a valid Quill document', () {
    final document = PlanDocument.fromJson({
      'id': 'draft-week',
      'title': 'Kế hoạch tuần',
      'date': '2026-08-24T00:00:00.000',
      'scope': 'Tuần',
      'contentDelta': <dynamic>[],
    });

    expect(document.editorDelta, [
      {'insert': '\n'},
    ]);
  });

  test('remote content without a trailing newline is normalized', () {
    final document = PlanDocument.fromJson({
      'id': 'draft-month',
      'title': 'Kế hoạch tháng 8',
      'date': '2026-08-01T00:00:00.000',
      'scope': 'Tháng',
      'contentDelta': [
        {'insert': 'Xu hướng chính'},
      ],
    });

    expect(document.editorDelta, [
      {'insert': 'Xu hướng chính'},
      {'insert': '\n'},
    ]);
  });

  test('plan status and inheritance metadata survive an offline restart', () {
    final original =
        PlanDocument.emptyFor(scope: 'Ngày', date: DateTime(2026, 9, 9))
          ..status = PlanStatus.completed
          ..inheritedPlanId = 'week-1'
          ..inheritedFrom = 'Plan tuần 07/09 - 13/09';

    final decoded = PlanDocument.fromJson(original.toJson());

    expect(decoded.status, PlanStatus.completed);
    expect(decoded.inheritedPlanId, 'week-1');
    expect(decoded.inheritedFrom, 'Plan tuần 07/09 - 13/09');
  });

  test(
    'repository returns default document when no local file exists',
    () async {
      final root = await Directory.systemTemp.createTemp('ttc-plan-test-');
      addTearDown(() => root.delete(recursive: true));
      final repository = PlanLocalRepository(
        documentsDirectory: () async => root,
      );

      final document = await repository.load();

      expect(document.title, isNotEmpty);
      expect(document.blocks, isNotEmpty);
      expect(File('${root.path}/offline_plan.json').existsSync(), isFalse);
    },
  );

  test('repository persists document and block order', () async {
    final root = await Directory.systemTemp.createTemp('ttc-plan-test-');
    addTearDown(() => root.delete(recursive: true));
    final repository = PlanLocalRepository(
      documentsDirectory: () async => root,
    );
    final document = PlanDocument(
      id: 'plan-persisted',
      title: 'Offline',
      date: DateTime(2026, 8, 28),
      scope: 'Tuần',
      session: 'New York',
      blocks: [PlanBlock.text('Một'), PlanBlock.text('Hai')],
    );

    await repository.save(document);
    final loaded = await repository.load();

    expect(loaded.id, 'plan-persisted');
    expect(loaded.title, 'Offline');
    expect(loaded.scope, 'Tuần');
    expect(loaded.blocks.map((block) => block.content), ['Một', 'Hai']);
    expect(loaded.updatedAt, isNotNull);
    expect(loaded.syncState, PlanSyncState.pendingSync);
  });
  test('repository keeps day, week, and month plans isolated', () async {
    final root = await Directory.systemTemp.createTemp('ttc-plan-test-');
    addTearDown(() => root.delete(recursive: true));
    final repository = PlanLocalRepository(
      documentsDirectory: () async => root,
    );

    final day =
        PlanDocument.emptyFor(scope: 'Ngày', date: DateTime(2026, 8, 27))
          ..contentDelta = [
            {'insert': 'Plan ngày 27'},
            {'insert': '\n'},
            {
              'insert': {'image': '${root.path}/plan_media/chart.jpg'},
            },
          ];
    final otherDay =
        PlanDocument.emptyFor(scope: 'Ngày', date: DateTime(2026, 8, 28))
          ..contentDelta = [
            {'insert': 'Plan ngày 28'},
            {'insert': '\n'},
          ];
    final week =
        PlanDocument.emptyFor(scope: 'Tuần', date: DateTime(2026, 8, 27))
          ..contentDelta = [
            {'insert': 'Plan tuần'},
            {'insert': '\n'},
          ];
    final month =
        PlanDocument.emptyFor(scope: 'Tháng', date: DateTime(2026, 8, 27))
          ..contentDelta = [
            {'insert': 'Plan tháng'},
            {'insert': '\n'},
          ];

    await repository.save(day);
    await repository.save(otherDay);
    await repository.save(week);
    await repository.save(month);

    final loadedDay = await repository.loadFor(
      scope: 'Ngày',
      date: DateTime(2026, 8, 27),
    );
    final loadedOtherDay = await repository.loadFor(
      scope: 'Ngày',
      date: DateTime(2026, 8, 28),
    );
    final loadedWeek = await repository.loadFor(
      scope: 'Tuần',
      date: DateTime(2026, 8, 29),
    );
    final loadedMonth = await repository.loadFor(
      scope: 'Tháng',
      date: DateTime(2026, 8, 1),
    );

    expect(loadedDay.contentDelta, contains(isA<Map>()));
    expect(loadedDay.contentDelta.toString(), contains('chart.jpg'));
    expect(loadedOtherDay.contentDelta.toString(), contains('Plan ngày 28'));
    expect(
      loadedOtherDay.contentDelta.toString(),
      isNot(contains('chart.jpg')),
    );
    expect(loadedWeek.contentDelta.toString(), contains('Plan tuần'));
    expect(loadedMonth.contentDelta.toString(), contains('Plan tháng'));
  });
}
