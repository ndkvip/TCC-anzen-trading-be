import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum OfflineSyncState {
  localOnly,
  pending,
  syncing,
  synced,
  failed,
  conflict;

  static OfflineSyncState fromJson(String? value) {
    if (value == null) return OfflineSyncState.localOnly;
    return OfflineSyncState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => throw FormatException('Trạng thái đồng bộ không hợp lệ'),
    );
  }
}

class OfflineSyncSnapshot {
  const OfflineSyncSnapshot({
    required this.state,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastError,
    this.updatedAt,
  });

  const OfflineSyncSnapshot.localOnly()
    : this(state: OfflineSyncState.localOnly);

  final OfflineSyncState state;
  final int pendingCount;
  final int failedCount;
  final String? lastError;
  final DateTime? updatedAt;

  bool get hasWork => pendingCount > 0 || failedCount > 0;

  String get label => switch (state) {
    OfflineSyncState.localOnly => 'Chỉ lưu trên thiết bị',
    OfflineSyncState.pending => 'Đang chờ đồng bộ',
    OfflineSyncState.syncing => 'Đang đồng bộ',
    OfflineSyncState.synced => 'Đã đồng bộ',
    OfflineSyncState.failed => 'Đồng bộ lỗi',
    OfflineSyncState.conflict => 'Cần xử lý xung đột',
  };
}

/// Small account-scoped JSON queue used by mutations that happen offline.
/// Records are deliberately idempotent: one logical key keeps only its latest
/// payload, so a user can edit repeatedly without creating duplicate uploads.
class OfflineSyncQueue {
  OfflineSyncQueue({
    required this.accountId,
    this.documentsDirectory = getApplicationDocumentsDirectory,
  });

  final String accountId;
  final Future<Directory> Function() documentsDirectory;
  static final Map<String, Future<void>> _tails = {};

  Future<T> _serialized<T>(Future<T> Function() action) {
    final lockKey = _lockKey;
    final previous = _tails[lockKey] ?? Future<void>.value();
    final result = previous.then((_) => action());
    _tails[lockKey] = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  String get _lockKey => 'offline-sync:${accountId.trim()}';

  Future<List<OfflineSyncItem>> load() => _serialized(_load);

  Future<List<OfflineSyncItem>> _load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        throw const FormatException('Queue phải là một mảng JSON');
      }
      final items = <OfflineSyncItem>[];
      for (final value in decoded) {
        if (value is! Map) {
          throw const FormatException('Bản ghi queue không phải object');
        }
        final item = OfflineSyncItem.fromJson(Map<String, dynamic>.from(value));
        if (item.key.trim().isEmpty) {
          throw const FormatException('Bản ghi queue thiếu key');
        }
        items.add(item);
      }
      return items;
    } catch (error, stack) {
      if (error is FormatException ||
          error is TypeError ||
          error is ArgumentError ||
          error is StateError) {
        throw OfflineSyncQueueCorruptionException(file.path, error, stack);
      }
      rethrow;
    }
  }

  Future<void> enqueue({
    required String key,
    required String type,
    required Map<String, dynamic> payload,
  }) => _serialized(() async {
    final items = await _load();
    final index = items.indexWhere((item) => item.key == key);
    final previous = index >= 0 ? items[index] : null;
    final next = OfflineSyncItem(
      key: key,
      type: type,
      payload: payload,
      state: OfflineSyncState.pending,
      retryCount: previous?.retryCount ?? 0,
      updatedAt: DateTime.now(),
    );
    if (index >= 0) {
      items[index] = next;
    } else {
      items.add(next);
    }
    await _write(items);
  });

  Future<void> markSyncing(String key) => _serialized(
    () => _update(
      key,
      (item) => item.copyWith(
        state: OfflineSyncState.syncing,
        lastError: null,
        updatedAt: DateTime.now(),
      ),
    ),
  );

  Future<void> markSynced(String key) => _serialized(() async {
    final items = await _load();
    items.removeWhere((item) => item.key == key);
    await _write(items);
  });

  Future<void> markFailed(String key, Object error, {bool conflict = false}) =>
      _serialized(
        () => _update(
          key,
          (item) => item.copyWith(
            state: conflict
                ? OfflineSyncState.conflict
                : OfflineSyncState.failed,
            retryCount: item.retryCount + 1,
            lastError: error.toString(),
            updatedAt: DateTime.now(),
          ),
        ),
      );

  Future<OfflineSyncSnapshot> snapshot() => _serialized(() async {
    List<OfflineSyncItem> items;
    try {
      items = await _load();
    } on OfflineSyncQueueCorruptionException catch (error) {
      return OfflineSyncSnapshot(
        state: OfflineSyncState.failed,
        failedCount: 1,
        lastError: error.toString(),
        updatedAt: DateTime.now(),
      );
    }
    if (items.isEmpty) return const OfflineSyncSnapshot.localOnly();
    final conflicts = items.where(
      (item) => item.state == OfflineSyncState.conflict,
    );
    final failed = items.where((item) => item.state == OfflineSyncState.failed);
    final syncing = items.where(
      (item) => item.state == OfflineSyncState.syncing,
    );
    final pending = items.where(
      (item) => item.state == OfflineSyncState.pending,
    );
    final state = conflicts.isNotEmpty
        ? OfflineSyncState.conflict
        : failed.isNotEmpty
        ? OfflineSyncState.failed
        : syncing.isNotEmpty
        ? OfflineSyncState.syncing
        : pending.isNotEmpty
        ? OfflineSyncState.pending
        : OfflineSyncState.synced;
    final issue = conflicts.isNotEmpty
        ? conflicts.first
        : failed.isNotEmpty
        ? failed.first
        : null;
    return OfflineSyncSnapshot(
      state: state,
      pendingCount: pending.length + syncing.length,
      failedCount: failed.length + conflicts.length,
      lastError: issue?.lastError,
      updatedAt: items
          .map((item) => item.updatedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b),
    );
  });

  Future<void> _update(
    String key,
    OfflineSyncItem Function(OfflineSyncItem item) transform,
  ) async {
    final items = await _load();
    final index = items.indexWhere((item) => item.key == key);
    if (index < 0) return;
    items[index] = transform(items[index]);
    await _write(items);
  }

  Future<File> _file() async {
    final root = await documentsDirectory();
    final safeId = accountId.trim().isEmpty
        ? 'guest'
        : accountId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final directory = Directory('${root.path}/sync');
    await directory.create(recursive: true);
    return File('${directory.path}/queue_$safeId.json');
  }

  Future<void> _write(List<OfflineSyncItem> items) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(items.map((item) => item.toJson()).toList()),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}

const _keepLastError = Object();

class OfflineSyncItem {
  const OfflineSyncItem({
    required this.key,
    required this.type,
    required this.payload,
    required this.state,
    required this.retryCount,
    required this.updatedAt,
    this.lastError,
  });

  factory OfflineSyncItem.fromJson(Map<String, dynamic> json) =>
      OfflineSyncItem(
        key: json['key'] as String? ?? '',
        type: json['type'] as String? ?? 'unknown',
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
        state: OfflineSyncState.fromJson(json['state'] as String?),
        retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        lastError: json['lastError'] as String?,
      );

  final String key;
  final String type;
  final Map<String, dynamic> payload;
  final OfflineSyncState state;
  final int retryCount;
  final DateTime updatedAt;
  final String? lastError;

  OfflineSyncItem copyWith({
    OfflineSyncState? state,
    int? retryCount,
    Object? lastError = _keepLastError,
    DateTime? updatedAt,
  }) => OfflineSyncItem(
    key: key,
    type: type,
    payload: payload,
    state: state ?? this.state,
    retryCount: retryCount ?? this.retryCount,
    lastError: identical(lastError, _keepLastError)
        ? this.lastError
        : lastError as String?,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'type': type,
    'payload': payload,
    'state': state.name,
    'retryCount': retryCount,
    'updatedAt': updatedAt.toIso8601String(),
    if (lastError != null) 'lastError': lastError,
  };
}

class OfflineSyncQueueCorruptionException implements Exception {
  const OfflineSyncQueueCorruptionException(this.path, this.cause, this.stack);

  final String path;
  final Object cause;
  final StackTrace stack;

  @override
  String toString() =>
      'Offline sync queue bị lỗi tại $path. Dữ liệu gốc được giữ nguyên: $cause';
}
