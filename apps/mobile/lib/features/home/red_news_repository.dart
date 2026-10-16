import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import 'red_news_model.dart';

class RedNewsRepository {
  RedNewsRepository({
    ApiClient? api,
    Future<Directory> Function()? documentsDirectory,
  }) : _api = api ?? ApiClient(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final ApiClient _api;
  final Future<Directory> Function() _documentsDirectory;
  DateTime? lastUpdated;
  bool lastLoadWasOnline = false;

  Future<List<RedNewsItem>> load() async {
    lastLoadWasOnline = false;
    try {
      final response = await _api
          .get('/red-news')
          .timeout(const Duration(seconds: 2));
      final rows = response['data'];
      if (rows is List) {
        final items = rows
            .whereType<Map>()
            .map((row) => RedNewsItem.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        // An empty response is still authoritative: the admin may have
        // removed or deactivated every event for the current week.
        lastUpdated = DateTime.now();
        lastLoadWasOnline = true;
        try {
          await _save(items);
        } catch (_) {
          // A local write failure must not discard a successful API response.
        }
        return items;
      }
    } catch (_) {
      // Offline-first: fall back to the last admin payload saved on this device.
    }

    final cached = await _loadCached();
    return cached ?? sampleRedNewsForWeek(DateTime.now());
  }

  Future<void> _save(List<RedNewsItem> items) async {
    final directory = await _documentsDirectory();
    final file = File('${directory.path}/red_news.json');
    await file.writeAsString(
      jsonEncode({
        'updatedAt': lastUpdated?.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      }),
    );
  }

  Future<List<RedNewsItem>?> _loadCached() async {
    try {
      final directory = await _documentsDirectory();
      final file = File('${directory.path}/red_news.json');
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(await file.readAsString());
      final rows = decoded is Map ? decoded['items'] : decoded;
      if (rows is! List) return null;
      if (decoded is Map) {
        lastUpdated = DateTime.tryParse(
          decoded['updatedAt']?.toString() ?? '',
        )?.toLocal();
      }
      return rows
          .whereType<Map>()
          .map((row) => RedNewsItem.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return null;
    }
  }
}

List<RedNewsItem> sampleRedNewsForWeek(DateTime reference) {
  final date = DateTime(reference.year, reference.month, reference.day);
  final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
  return [
    RedNewsItem(
      id: 'demo-cpi-${monday.toIso8601String()}',
      title: 'CPI Hoa Kỳ',
      currency: 'USD',
      description: 'Dữ liệu lạm phát quan trọng, có thể tạo biến động mạnh.',
      releaseAt: DateTime(monday.year, monday.month, monday.day + 1, 19, 30),
    ),
    RedNewsItem(
      id: 'demo-fed-${monday.toIso8601String()}',
      title: 'Quyết định lãi suất FED',
      currency: 'USD',
      description: 'Theo dõi phản ứng của giá trước và sau thời điểm công bố.',
      releaseAt: DateTime(monday.year, monday.month, monday.day + 3, 1),
    ),
    RedNewsItem(
      id: 'demo-nfp-${monday.toIso8601String()}',
      title: 'Non-Farm Payrolls',
      currency: 'USD',
      description:
          'Tin quan trọng cuối tuần dành cho các kế hoạch giao dịch có quản trị rủi ro.',
      releaseAt: DateTime(monday.year, monday.month, monday.day + 4, 19, 30),
    ),
  ];
}
