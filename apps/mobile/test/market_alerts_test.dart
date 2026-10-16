import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/features/personal/market_alerts_local_repository.dart';
import 'package:ttc_ict_mobile/features/personal/market_alerts_models.dart';

void main() {
  test('market alert settings persist all asset and session toggles', () async {
    final root = await Directory.systemTemp.createTemp(
      'ttc-market-alerts-test-',
    );
    addTearDown(() => root.delete(recursive: true));
    final repository = MarketAlertsLocalRepository(
      documentsDirectory: () async => root,
    );
    const settings = MarketAlertSettings(
      enabled: false,
      assetSettings: {
        'BTCUSDT': {'H4': false, 'Ngày': true, 'Tuần': true},
        'XAUUSD': {'H4': true, 'Ngày': false, 'Tuần': false},
      },
      usSession: false,
    );

    await repository.save(settings);
    final loaded = await repository.load();

    expect(loaded.enabled, isFalse);
    expect(loaded.assetSettings['BTCUSDT']?['Tuần'], isTrue);
    expect(loaded.assetSettings['XAUUSD']?['H4'], isTrue);
    expect(loaded.usSession, isFalse);
  });
}
