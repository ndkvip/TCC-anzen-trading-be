import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../home/red_news_model.dart';
import 'market_alert_schedule.dart';
import 'market_alerts_local_repository.dart';
import 'market_alerts_models.dart';
import 'checkin_notification_settings.dart';

class CheckinNotificationService {
  CheckinNotificationService._();

  static const _notificationId = 700;
  static const _redNewsNotificationStart = 200000;
  static const _marketNotificationStart = 300000;
  static const _marketNotificationEnd = 399999;
  // iOS keeps at most 64 pending local notifications. Reserve space for the
  // daily check-in and red-news alerts, then refresh this rolling window when
  // the app starts or a market-alert switch changes.
  static const _marketNotificationLimit = 48;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings: settings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    _initialized = true;
    final notificationSettings = await CheckinNotificationSettingsRepository()
        .load();
    await setDailyCheckinEnabled(notificationSettings.dailyCheckin);
    final marketSettings = await MarketAlertsLocalRepository().load();
    await scheduleMarketAlerts(marketSettings);
  }

  static Future<void> setDailyCheckinEnabled(bool enabled) async {
    if (!_initialized) return;
    if (!enabled) {
      await _plugin.cancel(id: _notificationId);
      return;
    }

    await _scheduleDailyCheckin();
  }

  static Future<void> _scheduleDailyCheckin() async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7);
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 7);
    }

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Điểm danh buổi sáng',
      body: 'Dành một phút kiểm tra trạng thái của bạn trước khi giao dịch.',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_checkin',
          'Điểm danh hàng ngày',
          channelDescription: 'Nhắc điểm danh lúc 07:00 mỗi ngày',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleMarketAlerts(MarketAlertSettings settings) async {
    if (!_initialized) return;
    await _cancelMarketAlerts();
    if (!settings.enabled) return;

    final vietnam = tz.getLocation('Asia/Ho_Chi_Minh');
    final now = tz.TZDateTime.now(vietnam);
    final occurrences = MarketAlertSchedule.upcoming(
      settings: settings,
      nowVietnam: DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      ),
      limit: _marketNotificationLimit,
    );

    for (var index = 0; index < occurrences.length; index++) {
      final occurrence = occurrences[index];
      final date = occurrence.atVietnam;
      final scheduledDate = tz.TZDateTime(
        vietnam,
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
      );
      await _plugin.zonedSchedule(
        id: _marketNotificationStart + index,
        title: _marketTitle(occurrence),
        body: _marketBody(occurrence),
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'market_candle_closes',
            'Đóng cửa nến thị trường',
            channelDescription:
                'Cảnh báo đóng cửa nến theo tài sản và khung thời gian',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  static Future<int> pendingMarketAlertCount() async {
    if (!_initialized) return 0;
    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .where(
          (item) =>
              item.id >= _marketNotificationStart &&
              item.id <= _marketNotificationEnd,
        )
        .length;
  }

  static Future<void> _cancelMarketAlerts() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.id >= _marketNotificationStart &&
          notification.id <= _marketNotificationEnd) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }

  static String _marketTitle(MarketAlertOccurrence occurrence) =>
      switch (occurrence.frame) {
        'H4' => 'Đóng cửa nến H4 · ${occurrence.asset}',
        'Ngày' => 'Đóng cửa nến ngày · ${occurrence.asset}',
        'Tháng' => 'Đóng cửa nến tháng · ${occurrence.asset}',
        _ => 'Cảnh báo thị trường · ${occurrence.asset}',
      };

  static String _marketBody(MarketAlertOccurrence occurrence) {
    final time = _formatDateTime(occurrence.atVietnam);
    return '${occurrence.asset} vừa đến mốc đóng nến ${occurrence.frame} lúc $time (GMT+7).';
  }

  static Future<void> scheduleRedNews(List<RedNewsItem> items) async {
    if (!_initialized) return;

    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.id >= _redNewsNotificationStart &&
          notification.id < _marketNotificationStart) {
        await _plugin.cancel(id: notification.id);
      }
    }

    for (final item in items) {
      final releaseAt = tz.TZDateTime.from(item.releaseAt, tz.local);
      final beforeAt = releaseAt.subtract(const Duration(minutes: 10));
      final now = tz.TZDateTime.now(tz.local);
      final baseId = _stableNotificationId(item.id);

      if (beforeAt.isAfter(now)) {
        await _scheduleRedNewsNotification(
          id: baseId,
          title: 'Tin quan trọng sau 10 phút',
          body: '${item.title} sẽ công bố lúc ${_formatTime(releaseAt)}.',
          scheduledDate: beforeAt,
        );
      }
      if (releaseAt.isAfter(now)) {
        await _scheduleRedNewsNotification(
          id: baseId + 1,
          title: 'Tin quan trọng vừa công bố',
          body: '${item.title} đang được phát hành.',
          scheduledDate: releaseAt,
        );
      }
    }
  }

  static Future<void> _scheduleRedNewsNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: scheduledDate,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'red_news',
        'Tin quan trọng trong tuần',
        channelDescription:
            'Nhắc tin quan trọng trước 10 phút và đúng thời điểm công bố',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );

  // String.hashCode is not guaranteed to be stable across app launches.
  static int _stableNotificationId(String value) {
    var hash = 17;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return _redNewsNotificationStart + (hash % 50000) * 2;
  }

  static String _formatTime(tz.TZDateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  static String _formatDateTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} '
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
