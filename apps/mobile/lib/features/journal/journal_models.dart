import '../../core/network/api_client.dart';

class TradeEntry {
  const TradeEntry({
    this.id,
    required this.symbol,
    required this.direction,
    required this.pnl,
    required this.r,
    required this.setup,
    required this.management,
    this.holding = '3.5 giờ',
    this.timeframePair = 'H4-M15',
    this.tradeDate,
    this.mode = 'INTRA_DAY',
    this.entryAt,
    this.imageUrls = const [],
    this.idea = '',
    this.execution = '',
    this.result = '',
    this.notesDelta = const [],
  });
  final String? id;
  final String symbol;
  final String direction;
  final double? pnl;
  final double r;
  final String setup;
  final String management;
  final String holding;
  final String timeframePair;
  final String? tradeDate;
  final String mode;
  final DateTime? entryAt;
  final List<String> imageUrls;
  final String idea;
  final String execution;
  final String result;
  final List<Map<String, dynamic>> notesDelta;
  bool get isRunning => pnl == null;

  factory TradeEntry.fromJson(Map<String, dynamic> json) => TradeEntry(
    id: json['id'] as String?,
    symbol: json['symbol'] as String? ?? 'BTCUSDT',
    direction: json['direction'] == 'SHORT' || json['direction'] == 'Short'
        ? 'Short'
        : 'Long',
    pnl: (json['pnl'] as num?)?.toDouble(),
    r:
        (json['riskReward'] as num?)?.toDouble() ??
        (json['r'] as num?)?.toDouble() ??
        0,
    setup:
        json['priceMovement'] as String? ?? json['setup'] as String? ?? 'AMD',
    management: json['management'] as String? ?? 'Xử lý lệnh',
    holding: _holdingLabel(json),
    timeframePair: json['timeframePair'] as String? ?? 'H4-M15',
    tradeDate: json['tradeDate'] as String?,
    mode: json['mode'] as String? ?? 'INTRA_DAY',
    entryAt: DateTime.tryParse(json['entryAt'] as String? ?? ''),
    imageUrls: (json['processImageUrls'] as List? ?? const [])
        .whereType<String>()
        .toList(),
    idea: json['idea'] as String? ?? '',
    execution: json['execution'] as String? ?? '',
    result: json['result'] as String? ?? '',
    notesDelta: (json['notesDelta'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(),
  );

  Map<String, dynamic> toJson({String? date, String? journalMode}) => {
    if (id != null && !id!.startsWith('local-')) 'id': id,
    'symbol': symbol,
    'direction': direction.toUpperCase(),
    'pnl': pnl,
    'riskReward': r,
    'priceMovement': setup,
    'management': management,
    'holdingHours':
        double.tryParse(holding.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
    'timeframePair': timeframePair,
    'tradeDate': journalMode == 'SWING' ? null : (date ?? tradeDate),
    'mode': journalMode ?? mode,
    if (entryAt != null) 'entryAt': entryAt!.toIso8601String(),
    'processImageUrls': imageUrls,
    'idea': idea,
    'execution': execution,
    'result': result,
    'notesDelta': notesDelta,
  };
}

TradeEntry? highestClosedRRTrade(Iterable<TradeEntry> trades) {
  final closed = trades.where((trade) => !trade.isRunning).toList();
  if (closed.isEmpty) return null;
  return closed.reduce((best, trade) => trade.r > best.r ? trade : best);
}

class SwingStrategySummary {
  const SwingStrategySummary({
    required this.timeframePair,
    required this.setup,
    required this.pnl,
    required this.totalR,
    required this.tradeCount,
    required this.wins,
  });

  final String timeframePair;
  final String setup;
  final double pnl;
  final double totalR;
  final int tradeCount;
  final int wins;

  double get winRate => tradeCount == 0 ? 0 : wins / tradeCount * 100;
  String get label => '$timeframePair · $setup';
}

SwingStrategySummary? bestSwingStrategy(Iterable<TradeEntry> trades) {
  final grouped = <String, List<TradeEntry>>{};
  for (final trade in trades.where((trade) => !trade.isRunning)) {
    final timeframe = trade.timeframePair.trim().isEmpty
        ? 'Chưa chọn khung'
        : trade.timeframePair.trim();
    final setup = trade.setup.trim().isEmpty
        ? 'Chưa phân loại'
        : trade.setup.trim();
    (grouped['$timeframe|$setup'] ??= []).add(trade);
  }
  if (grouped.isEmpty) return null;

  SwingStrategySummary summary(List<TradeEntry> values) {
    final first = values.first;
    final pnl = values.fold<double>(
      0,
      (sum, trade) => sum + (trade.pnl ?? 0),
    );
    final totalR = values.fold<double>(0, (sum, trade) => sum + trade.r);
    final wins = values.where((trade) => (trade.pnl ?? 0) > 0).length;
    return SwingStrategySummary(
      timeframePair: first.timeframePair.trim().isEmpty
          ? 'Chưa chọn khung'
          : first.timeframePair.trim(),
      setup: first.setup.trim().isEmpty ? 'Chưa phân loại' : first.setup.trim(),
      pnl: pnl,
      totalR: totalR,
      tradeCount: values.length,
      wins: wins,
    );
  }

  return grouped.values
      .map(summary)
      .reduce((best, current) {
        if (current.pnl != best.pnl) {
          return current.pnl > best.pnl ? current : best;
        }
        if (current.totalR != best.totalR) {
          return current.totalR > best.totalR ? current : best;
        }
        return current.tradeCount > best.tradeCount ? current : best;
      });
}

String _holdingLabel(Map<String, dynamic> json) {
  final raw = (json['holdingHours'] as num?)?.toDouble() ?? json['holding'];
  if (raw == null) return '0 giờ';
  final text = raw is num
      ? (raw % 1 == 0 ? raw.toInt().toString() : raw.toString())
      : raw.toString().replaceFirst(
          RegExp(r'\s*giờ\s*$', caseSensitive: false),
          '',
        );
  return '$text giờ';
}

class FeaturedTradeBlock {
  const FeaturedTradeBlock({required this.type, this.text, this.imageUrl});

  final String type;
  final String? text;
  final String? imageUrl;

  bool get isText => type == 'text';
  bool get isImage => type == 'image';

  factory FeaturedTradeBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'] == 'image' ? 'image' : 'text';
    final text = json['text'] as String?;
    final image = json['imageUrl'] as String?;
    return FeaturedTradeBlock(
      type: type,
      text: text?.trim(),
      imageUrl: image == null || image.trim().isEmpty
          ? null
          : _featuredMediaUrl(image),
    );
  }
}

class FeaturedTrade {
  const FeaturedTrade({
    required this.id,
    required this.weekStart,
    required this.title,
    required this.summary,
    required this.coverImageUrl,
    required this.contentBlocks,
    required this.isActive,
  });

  final String id;
  final String weekStart;
  final String title;
  final String? summary;
  final String? coverImageUrl;
  final List<FeaturedTradeBlock> contentBlocks;
  final bool isActive;

  List<String> get imageUrls => contentBlocks
      .where((block) => block.isImage && block.imageUrl != null)
      .map((block) => block.imageUrl!)
      .toList(growable: false);

  String? get previewImage =>
      coverImageUrl ?? (imageUrls.isEmpty ? null : imageUrls.first);

  factory FeaturedTrade.fromJson(Map<String, dynamic> json) {
    final legacyImages = (json['imageUrls'] as List? ?? const [])
        .whereType<String>()
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .map(
          (url) => FeaturedTradeBlock(
            type: 'image',
            imageUrl: _featuredMediaUrl(url),
          ),
        )
        .toList();
    final rawBlocks = (json['contentBlocks'] as List? ?? const []);
    final blocks = rawBlocks
        .whereType<Map>()
        .map(
          (block) =>
              FeaturedTradeBlock.fromJson(Map<String, dynamic>.from(block)),
        )
        .where(
          (block) => block.isText
              ? (block.text?.isNotEmpty ?? false)
              : block.imageUrl != null,
        )
        .toList();
    final content = blocks.isEmpty ? legacyImages : blocks;
    final rawCover = json['coverImageUrl'] as String?;
    return FeaturedTrade(
      id: json['id'] as String? ?? '',
      weekStart: json['weekStart'] as String? ?? '',
      title: (json['title'] as String? ?? '').trim(),
      summary: (json['summary'] as String?)?.trim(),
      coverImageUrl: rawCover == null || rawCover.trim().isEmpty
          ? null
          : _featuredMediaUrl(rawCover),
      contentBlocks: content,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

String _mediaUrl(String path) {
  final uri = Uri.tryParse(path);
  return uri?.hasScheme == true ? path : '${ApiClient.baseUrl}$path';
}

String _featuredMediaUrl(String path) {
  final uri = Uri.tryParse(path);
  if (uri?.host == 'drive.google.com') {
    final segments = uri!.pathSegments;
    final id =
        uri.queryParameters['id'] ??
        (segments.length >= 3 && segments[0] == 'file' && segments[1] == 'd'
            ? segments[2]
            : null);
    if (id != null) {
      return '${ApiClient.baseUrl}/featured-trades/drive-images/${Uri.encodeComponent(id)}';
    }
  }
  return _mediaUrl(path);
}

List<String> journalNoteImages(List<Map<String, dynamic>> delta) => delta
    .map((operation) => operation['insert'])
    .whereType<Map>()
    .map((embed) => embed['image'])
    .whereType<String>()
    .toSet()
    .toList();

List<Map<String, dynamic>> replaceJournalNoteImages(
  List<Map<String, dynamic>> delta,
  Map<String, String> replacements,
) => delta.map((operation) {
  final insert = operation['insert'];
  if (insert is Map && insert['image'] is String) {
    final image = insert['image'] as String;
    return <String, dynamic>{
      ...operation,
      'insert': {'image': replacements[image] ?? image},
    };
  }
  return Map<String, dynamic>.from(operation);
}).toList();
