import 'market_alerts_models.dart';

class MarketAlertOccurrence {
  const MarketAlertOccurrence({
    required this.asset,
    required this.frame,
    required this.atVietnam,
  });

  final String asset;
  final String frame;
  final DateTime atVietnam;
}

abstract final class MarketAlertSchedule {
  static const supportedAssets = {'BTCUSDT', 'XAUUSD'};
  static const scheduledFrames = {'H4', 'Ngày', 'Tuần', 'Tháng'};

  static bool supports(String asset, String frame) =>
      supportedAssets.contains(asset) && scheduledFrames.contains(frame);

  static bool usesWinterShift(DateTime vietnamDate) {
    final date = DateTime(vietnamDate.year, vietnamDate.month, vietnamDate.day);
    final seasonStartYear = date.month >= DateTime.november
        ? date.year
        : date.year - 1;
    final start = nthSunday(seasonStartYear, DateTime.november, 1);
    final end = nthSunday(seasonStartYear + 1, DateTime.march, 2);
    return !date.isBefore(start) && date.isBefore(end);
  }

  static DateTime nthSunday(int year, int month, int occurrence) {
    final first = DateTime(year, month, 1);
    final daysUntilSunday =
        (DateTime.sunday - first.weekday + DateTime.daysPerWeek) %
        DateTime.daysPerWeek;
    return DateTime(year, month, 1 + daysUntilSunday + (occurrence - 1) * 7);
  }

  static List<int> h4Hours(String asset, DateTime vietnamDate) {
    final base = switch (asset) {
      'BTCUSDT' => const [3, 7, 11, 15, 19, 23],
      'XAUUSD' => const [1, 5, 9, 13, 17, 21],
      _ => const <int>[],
    };
    final shift = usesWinterShift(vietnamDate) ? 1 : 0;
    return base.map((hour) => (hour + shift) % 24).toList()..sort();
  }

  static int? dailyHour(String asset, DateTime vietnamDate) {
    final base = switch (asset) {
      'BTCUSDT' => 7,
      'XAUUSD' => 5,
      _ => null,
    };
    if (base == null) return null;
    return base + (usesWinterShift(vietnamDate) ? 1 : 0);
  }

  static int? weeklyHourFor(String asset, DateTime vietnamDate) {
    final isWeeklyCloseDay = switch (asset) {
      'BTCUSDT' => vietnamDate.weekday == DateTime.monday,
      'XAUUSD' => vietnamDate.weekday == DateTime.friday,
      _ => false,
    };
    if (!isWeeklyCloseDay) return null;

    final base = switch (asset) {
      'BTCUSDT' => 7,
      'XAUUSD' => 21,
      _ => null,
    };
    if (base == null) return null;
    return base + (usesWinterShift(vietnamDate) ? 1 : 0);
  }

  static List<MarketAlertOccurrence> upcoming({
    required MarketAlertSettings settings,
    required DateTime nowVietnam,
    int limit = 48,
    int horizonDays = 400,
  }) {
    if (!settings.enabled || limit <= 0) return const [];

    final occurrences = <MarketAlertOccurrence>[];
    final startDate = DateTime(
      nowVietnam.year,
      nowVietnam.month,
      nowVietnam.day,
    );

    for (var offset = 0; offset <= horizonDays; offset++) {
      final date = startDate.add(Duration(days: offset));
      for (final asset in supportedAssets) {
        final frames = settings.assetSettings[asset] ?? const <String, bool>{};

        if (frames['H4'] == true && _isTradingDay(date)) {
          for (final hour in h4Hours(asset, date)) {
            if (date.weekday == DateTime.monday && hour < 5) continue;
            _addIfFuture(
              occurrences,
              nowVietnam,
              asset,
              'H4',
              DateTime(date.year, date.month, date.day, hour),
            );
          }
        }

        if (frames['Ngày'] == true && _isTradingDay(date)) {
          final hour = dailyHour(asset, date);
          if (hour != null) {
            _addIfFuture(
              occurrences,
              nowVietnam,
              asset,
              'Ngày',
              DateTime(date.year, date.month, date.day, hour),
            );
          }
        }

        if (frames['Tuần'] == true) {
          final weeklyHour = weeklyHourFor(asset, date);
          if (weeklyHour != null) {
            _addIfFuture(
              occurrences,
              nowVietnam,
              asset,
              'Tuần',
              DateTime(date.year, date.month, date.day, weeklyHour),
            );
          }
        }

        if (frames['Tháng'] == true && _isLastDayOfMonth(date)) {
          final hour = dailyHour(asset, date);
          if (hour != null) {
            _addIfFuture(
              occurrences,
              nowVietnam,
              asset,
              'Tháng',
              DateTime(date.year, date.month, date.day, hour),
            );
          }
        }
      }
    }

    occurrences.sort((a, b) => a.atVietnam.compareTo(b.atVietnam));
    return occurrences.take(limit).toList(growable: false);
  }

  static bool _isTradingDay(DateTime date) =>
      date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;

  static bool _isLastDayOfMonth(DateTime date) =>
      date.day == DateTime(date.year, date.month + 1, 0).day;

  static void _addIfFuture(
    List<MarketAlertOccurrence> target,
    DateTime now,
    String asset,
    String frame,
    DateTime at,
  ) {
    if (at.isAfter(now)) {
      target.add(
        MarketAlertOccurrence(asset: asset, frame: frame, atVietnam: at),
      );
    }
  }
}
