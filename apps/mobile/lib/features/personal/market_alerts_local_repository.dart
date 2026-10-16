import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'market_alerts_models.dart';

class MarketAlertsLocalRepository {
  MarketAlertsLocalRepository({
    this.documentsDirectory = getApplicationDocumentsDirectory,
  });

  final Future<Directory> Function() documentsDirectory;

  Future<MarketAlertSettings> load() async {
    final file = await _file();
    if (!await file.exists()) return const MarketAlertSettings();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return MarketAlertSettings.fromJson(decoded);
      }
    } catch (_) {}
    return const MarketAlertSettings();
  }

  Future<void> save(MarketAlertSettings settings) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<File> _file() async {
    final directory = await documentsDirectory();
    return File('${directory.path}/market_alert_settings.json');
  }
}
