import 'package:flutter_test/flutter_test.dart';
import 'package:ttc_ict_mobile/features/personal/market_alert_schedule.dart';
import 'package:ttc_ict_mobile/features/personal/market_alerts_models.dart';

void main() {
  group('market alert schedule GMT+7', () {
    test('applies the requested winter one-hour shift', () {
      expect(
        MarketAlertSchedule.usesWinterShift(DateTime(2026, 10, 31)),
        isFalse,
      );
      expect(
        MarketAlertSchedule.usesWinterShift(DateTime(2026, 11, 1)),
        isTrue,
      );
      expect(
        MarketAlertSchedule.usesWinterShift(DateTime(2027, 3, 13)),
        isTrue,
      );
      expect(
        MarketAlertSchedule.usesWinterShift(DateTime(2027, 3, 14)),
        isFalse,
      );

      expect(MarketAlertSchedule.h4Hours('BTCUSDT', DateTime(2026, 10, 30)), [
        3,
        7,
        11,
        15,
        19,
        23,
      ]);
      expect(MarketAlertSchedule.h4Hours('BTCUSDT', DateTime(2026, 11, 2)), [
        0,
        4,
        8,
        12,
        16,
        20,
      ]);
      expect(MarketAlertSchedule.h4Hours('XAUUSD', DateTime(2026, 11, 2)), [
        2,
        6,
        10,
        14,
        18,
        22,
      ]);
    });

    test('starts the weekly schedule from Monday 05:00', () {
      const settings = MarketAlertSettings(
        assetSettings: {
          'BTCUSDT': {'H4': true, 'Ngày': false, 'Tuần': false, 'Tháng': false},
          'XAUUSD': {'H4': true, 'Ngày': false, 'Tuần': false, 'Tháng': false},
        },
      );
      final events = MarketAlertSchedule.upcoming(
        settings: settings,
        nowVietnam: DateTime(2026, 11, 2, 4),
        limit: 4,
      );

      expect(events.first.asset, 'XAUUSD');
      expect(events.first.atVietnam, DateTime(2026, 11, 2, 6));
      expect(events[1].asset, 'BTCUSDT');
      expect(events[1].atVietnam, DateTime(2026, 11, 2, 8));
      expect(events.any((event) => event.atVietnam.hour < 5), isFalse);
    });

    test('schedules weekly closes for BTC on Monday and gold on Friday', () {
      const settings = MarketAlertSettings(
        assetSettings: {
          'BTCUSDT': {'H4': false, 'Ngày': false, 'Tuần': true, 'Tháng': false},
          'XAUUSD': {'H4': false, 'Ngày': false, 'Tuần': true, 'Tháng': false},
        },
      );

      final standard = MarketAlertSchedule.upcoming(
        settings: settings,
        nowVietnam: DateTime(2026, 8, 30),
        limit: 2,
      );
      expect(standard[0].asset, 'BTCUSDT');
      expect(standard[0].frame, 'Tuần');
      expect(standard[0].atVietnam, DateTime(2026, 8, 31, 7));
      expect(standard[1].asset, 'XAUUSD');
      expect(standard[1].atVietnam, DateTime(2026, 9, 4, 21));

      final shifted = MarketAlertSchedule.upcoming(
        settings: settings,
        nowVietnam: DateTime(2026, 11, 1),
        limit: 2,
      );
      expect(shifted[0].asset, 'BTCUSDT');
      expect(shifted[0].atVietnam, DateTime(2026, 11, 2, 8));
      expect(shifted[1].asset, 'XAUUSD');
      expect(shifted[1].atVietnam, DateTime(2026, 11, 6, 22));
    });

    test('uses the last calendar day for monthly close', () {
      const settings = MarketAlertSettings(
        assetSettings: {
          'BTCUSDT': {'H4': false, 'Ngày': false, 'Tuần': false, 'Tháng': true},
          'XAUUSD': {'H4': false, 'Ngày': false, 'Tuần': false, 'Tháng': true},
        },
      );
      final events = MarketAlertSchedule.upcoming(
        settings: settings,
        nowVietnam: DateTime(2026, 8, 1),
        limit: 4,
      );

      expect(events[0].asset, 'XAUUSD');
      expect(events[0].atVietnam, DateTime(2026, 8, 31, 5));
      expect(events[1].asset, 'BTCUSDT');
      expect(events[1].atVietnam, DateTime(2026, 8, 31, 7));
      expect(events[2].asset, 'XAUUSD');
      expect(events[2].atVietnam, DateTime(2026, 9, 30, 5));
      expect(events[3].asset, 'BTCUSDT');
      expect(events[3].atVietnam, DateTime(2026, 9, 30, 7));
    });
  });
}
