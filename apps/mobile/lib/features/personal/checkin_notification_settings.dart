import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Device-level preferences for local personal notifications.
///
/// These settings intentionally live on the device rather than in the API:
/// the notification schedule is owned by the operating system and does not
/// require a signed-in account.
class CheckinNotificationSettings {
  const CheckinNotificationSettings({this.dailyCheckin = true});

  final bool dailyCheckin;

  CheckinNotificationSettings copyWith({bool? dailyCheckin}) =>
      CheckinNotificationSettings(
        dailyCheckin: dailyCheckin ?? this.dailyCheckin,
      );

  Map<String, dynamic> toJson() => {'dailyCheckin': dailyCheckin};

  factory CheckinNotificationSettings.fromJson(Map<String, dynamic> json) =>
      CheckinNotificationSettings(dailyCheckin: json['dailyCheckin'] != false);
}

class CheckinNotificationSettingsRepository {
  CheckinNotificationSettingsRepository({
    this.documentsDirectory = getApplicationDocumentsDirectory,
  });

  final Future<Directory> Function() documentsDirectory;

  Future<CheckinNotificationSettings> load() async {
    final file = await _file();
    if (!await file.exists()) return const CheckinNotificationSettings();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        return CheckinNotificationSettings.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } on FormatException {
      // A malformed preference falls back to the safe default.
    } on IOException {
      // Keep notifications usable even when the cache cannot be read.
    }
    return const CheckinNotificationSettings();
  }

  Future<void> save(CheckinNotificationSettings settings) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }

  Future<File> _file() async {
    final directory = await documentsDirectory();
    return File('${directory.path}/checkin_notification_settings.json');
  }
}
