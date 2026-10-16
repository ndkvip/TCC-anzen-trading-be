import 'package:flutter/material.dart';

/// A document is made of ordered blocks so text and images can be interleaved
/// without forcing the user into a card-based layout.
class PlanDocument {
  PlanDocument({
    required this.id,
    required this.title,
    required this.date,
    required this.scope,
    required this.session,
    required this.blocks,
    this.timeframePairs = const [],
    this.contentDelta,
    this.updatedAt,
    this.syncState = PlanSyncState.localOnly,
    this.syncError,
    this.syncRetryCount = 0,
    this.lastSyncedAt,
    this.status = PlanStatus.draft,
    this.inheritedPlanId,
    this.inheritedFrom,
  });

  factory PlanDocument.defaultDocument({DateTime? date}) {
    final selectedDate = date ?? DateTime(2026, 8, 27);
    return PlanDocument(
      id: 'plan-${selectedDate.toIso8601String().split('T').first}',
      title: 'Kế hoạch giao dịch - XAUUSD',
      date: selectedDate,
      scope: 'Ngày',
      session: 'London session',
      timeframePairs: ['H4-M15', 'H1-M5'],
      blocks: [
        PlanBlock.text('Bối cảnh', bold: true, colorHint: 'section'),
        PlanBlock.text(
          'XAUUSD đang duy trì xu hướng giảm. Chờ giá hồi về vùng FVG H4 để quan sát phản ứng và tìm điểm vào lệnh.',
        ),
        PlanBlock.image(''),
        PlanBlock.text(
          'Kịch bản ưu tiên: Short khi giá phản ứng tại vùng FVG.\n\nKhông vào lệnh trước khi có tín hiệu xác nhận.',
        ),
      ],
    );
  }

  factory PlanDocument.emptyFor({
    required String scope,
    required DateTime date,
  }) {
    final title = switch (scope) {
      'Tuần' => 'Kế hoạch tuần',
      'Tháng' => 'Kế hoạch tháng ${date.month}',
      _ => 'Kế hoạch giao dịch - XAUUSD',
    };
    return PlanDocument(
      id: 'plan-${scope.toLowerCase()}-${date.toIso8601String().split('T').first}',
      title: title,
      date: date,
      scope: scope,
      session: 'London session',
      blocks: [PlanBlock.text('')],
    );
  }

  factory PlanDocument.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];
    return PlanDocument(
      id: json['id'] as String? ?? 'local-plan',
      title: json['title'] as String? ?? 'Kế hoạch giao dịch',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      scope: json['scope'] as String? ?? 'Ngày',
      session: json['session'] as String? ?? 'London session',
      timeframePairs: (json['timeframePairs'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      contentDelta: json['contentDelta'] is List
          ? List<dynamic>.from(json['contentDelta'] as List)
          : null,
      blocks: rawBlocks is List
          ? rawBlocks
                .whereType<Map>()
                .map(
                  (block) =>
                      PlanBlock.fromJson(Map<String, dynamic>.from(block)),
                )
                .toList()
          : [PlanBlock.text('Bắt đầu viết kế hoạch của bạn...')],
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      syncState: PlanSyncState.fromJson(json['syncState'] as String?),
      syncError: json['syncError'] as String?,
      syncRetryCount: (json['syncRetryCount'] as num?)?.toInt() ?? 0,
      lastSyncedAt: DateTime.tryParse(json['lastSyncedAt'] as String? ?? ''),
      status: PlanStatus.fromJson(json['status'] as String?),
      inheritedPlanId: json['inheritedPlanId'] as String?,
      inheritedFrom: json['inheritedFrom'] as String?,
    );
  }

  String id;
  String title;
  DateTime date;
  String scope;
  String session;
  List<String> timeframePairs;
  List<PlanBlock> blocks;

  /// Quill Delta is the source of truth for the Word-like editor.
  /// `blocks` remains for backwards-compatible local documents and tests.
  List<dynamic>? contentDelta;

  List<dynamic> get editorDelta =>
      _normalizeDelta(contentDelta ?? _deltaFromBlocks(blocks));
  DateTime? updatedAt;
  PlanSyncState syncState;
  String? syncError;
  int syncRetryCount;
  DateTime? lastSyncedAt;
  PlanStatus status;
  String? inheritedPlanId;
  String? inheritedFrom;

  PlanDocument copy() => PlanDocument.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'scope': scope,
    'session': session,
    'timeframePairs': timeframePairs,
    'blocks': blocks.map((block) => block.toJson()).toList(),
    if (contentDelta != null) 'contentDelta': contentDelta,
    'updatedAt': updatedAt?.toIso8601String(),
    'syncState': syncState.name,
    if (syncError != null) 'syncError': syncError,
    'syncRetryCount': syncRetryCount,
    if (lastSyncedAt != null) 'lastSyncedAt': lastSyncedAt!.toIso8601String(),
    'status': status.name,
    if (inheritedPlanId != null) 'inheritedPlanId': inheritedPlanId,
    if (inheritedFrom != null) 'inheritedFrom': inheritedFrom,
  };
}

List<dynamic> _normalizeDelta(List<dynamic> delta) {
  if (delta.isEmpty) {
    return const [
      {'insert': '\n'},
    ];
  }

  final normalized = List<dynamic>.from(delta);
  final lastOperation = normalized.last;
  final lastInsert = lastOperation is Map ? lastOperation['insert'] : null;
  if (lastInsert is! String || !lastInsert.endsWith('\n')) {
    normalized.add({'insert': '\n'});
  }
  return normalized;
}

List<dynamic> _deltaFromBlocks(List<PlanBlock> blocks) {
  final operations = <dynamic>[];
  for (final block in blocks) {
    if (block.type == PlanBlockType.image && block.content.isNotEmpty) {
      operations.add({
        'insert': {'image': block.content},
      });
      operations.add({'insert': '\n'});
      continue;
    }
    final attributes = <String, dynamic>{};
    if (block.bold) attributes['bold'] = true;
    if (block.italic) attributes['italic'] = true;
    if (block.alignment != TextAlign.left) {
      attributes['align'] = switch (block.alignment) {
        TextAlign.center => 'center',
        TextAlign.right => 'right',
        _ => 'left',
      };
    }
    if (block.content.isNotEmpty) {
      operations.add({
        'insert': block.content,
        if (attributes.isNotEmpty) 'attributes': attributes,
      });
    }
    operations.add({'insert': '\n'});
  }
  if (operations.isEmpty) operations.add({'insert': '\n'});
  return operations;
}

enum PlanBlockType { text, image }

enum PlanStatus {
  draft,
  completed;

  static PlanStatus fromJson(String? value) => PlanStatus.values.firstWhere(
    (status) => status.name.toUpperCase() == value?.toUpperCase(),
    orElse: () => PlanStatus.draft,
  );
}

enum PlanSyncState {
  localOnly,
  pendingSync,
  syncing,
  synced,
  failed,
  conflict;

  static PlanSyncState fromJson(String? value) =>
      PlanSyncState.values.firstWhere(
        (state) => state.name == value,
        orElse: () => PlanSyncState.localOnly,
      );
}

class PlanBlock {
  PlanBlock({
    required this.id,
    required this.type,
    required this.content,
    this.bold = false,
    this.italic = false,
    this.alignment = TextAlign.left,
    this.colorHint,
  });

  factory PlanBlock.text(
    String content, {
    bool bold = false,
    bool italic = false,
    TextAlign alignment = TextAlign.left,
    String? colorHint,
  }) => PlanBlock(
    id: _newBlockId(),
    type: PlanBlockType.text,
    content: content,
    bold: bold,
    italic: italic,
    alignment: alignment,
    colorHint: colorHint,
  );

  factory PlanBlock.image(String path) =>
      PlanBlock(id: _newBlockId(), type: PlanBlockType.image, content: path);

  factory PlanBlock.fromJson(Map<String, dynamic> json) => PlanBlock(
    id: json['id'] as String? ?? _newBlockId(),
    type: json['type'] == 'image' ? PlanBlockType.image : PlanBlockType.text,
    content: json['content'] as String? ?? '',
    bold: json['bold'] as bool? ?? false,
    italic: json['italic'] as bool? ?? false,
    alignment: _textAlignFromJson(json['alignment'] as String?),
    colorHint: json['colorHint'] as String?,
  );

  final String id;
  final PlanBlockType type;
  String content;
  bool bold;
  bool italic;
  TextAlign alignment;
  String? colorHint;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'content': content,
    'bold': bold,
    'italic': italic,
    'alignment': alignment.name,
    if (colorHint != null) 'colorHint': colorHint,
  };

  PlanBlock copy() => PlanBlock.fromJson(toJson());
}

String _newBlockId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
int _idCounter = 0;

TextAlign _textAlignFromJson(String? value) => TextAlign.values.firstWhere(
  (alignment) => alignment.name == value,
  orElse: () => TextAlign.left,
);
