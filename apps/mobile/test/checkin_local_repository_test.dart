import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/features/personal/checkin_local_repository.dart';
import 'package:ttc_ict_mobile/features/personal/personal_models.dart';

void main() {
  test('check-in history persists and is capped at 30 days', () async {
    final root = await Directory.systemTemp.createTemp('ttc-checkin-test-');
    addTearDown(() => root.delete(recursive: true));
    final repository = CheckinLocalRepository(
      documentsDirectory: () async => root,
    );

    await repository.save([
      for (var index = 0; index < 31; index++)
        CheckinEntry(
          date: DateTime(2026, 8, 1 + index),
          scores: [0, 1, 2, 3, 4],
        ),
    ]);

    final loaded = await repository.load();
    expect(loaded, hasLength(30));
    expect(loaded.first.date, DateTime(2026, 8, 31));
    expect(loaded.last.date, DateTime(2026, 8, 2));
  });

  test('check-in history is isolated by account', () async {
    final root = await Directory.systemTemp.createTemp(
      'ttc-checkin-account-test-',
    );
    addTearDown(() => root.delete(recursive: true));
    final accountA = CheckinLocalRepository(
      documentsDirectory: () async => root,
      accountId: 'user-a',
    );
    final accountB = CheckinLocalRepository(
      documentsDirectory: () async => root,
      accountId: 'user-b',
    );

    await accountA.save([
      CheckinEntry(date: DateTime(2026, 8, 31), scores: [4, 4, 4, 4, 4]),
    ]);
    expect(await accountA.load(), hasLength(1));
    expect(await accountB.load(), isEmpty);
  });
}
