import 'package:ttc_ict_mobile/core/network/api_client.dart';
import 'package:ttc_ict_mobile/features/journal/journal_models.dart';

class FeaturedTradeRepository {
  FeaturedTradeRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  String? _cachedWeek;
  List<FeaturedTrade> _cachedTrades = const [];

  Future<List<FeaturedTrade>> load(DateTime date) async {
    final monday = DateTime(
      date.year,
      date.month,
      date.day - (date.weekday - 1),
    );
    final week = _dateKey(monday);
    try {
      final response = await _api.get('/featured-trades?week=$week');
      final value = response.containsKey('data') ? response['data'] : response;
      final values = value is List
          ? value
          : value is Map
          ? <dynamic>[value]
          : const <dynamic>[];
      final trades = values
          .whereType<Map>()
          .map(
            (item) => FeaturedTrade.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((trade) => trade.isActive && trade.contentBlocks.isNotEmpty)
          .toList(growable: false);
      _cachedWeek = week;
      _cachedTrades = trades;
      return trades;
    } catch (_) {
      // Home can continue rendering when featured content is offline.
      return _cachedWeek == week ? _cachedTrades : const [];
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
