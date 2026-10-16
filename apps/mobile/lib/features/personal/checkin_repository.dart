import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import '../../core/sync/offline_sync.dart';
import '../auth/auth_controller.dart';
import 'checkin_local_repository.dart';
import 'personal_models.dart';

/// Account-scoped local cache with a durable retry queue for server writes.
class CheckinRepository {
  CheckinRepository({
    required this.auth,
    Future<Directory> Function()? documentsDirectory,
    ApiClient? api,
  }) : _local = CheckinLocalRepository(
         accountId: auth.user?.id ?? 'guest',
         documentsDirectory: documentsDirectory,
       ),
       _api = api ?? ApiClient() {
    _queue = OfflineSyncQueue(
      accountId: auth.user?.id ?? 'guest',
      documentsDirectory:
          documentsDirectory ?? getApplicationDocumentsDirectory,
    );
  }

  final AuthController auth;
  final CheckinLocalRepository _local;
  final ApiClient _api;
  late final OfflineSyncQueue _queue;
  Future<void> _tail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String? lastSyncError;
  int pendingCount = 0;
  OfflineSyncState syncState = OfflineSyncState.localOnly;

  Future<List<CheckinEntry>> load() => _serialized(_load);

  Future<List<CheckinEntry>> _load() async {
    final cached = await _local.load();
    try {
      pendingCount = (await _queue.load()).length;
      if (!auth.isAuthenticated) return cached;
      await _syncPending();
      final response = await auth.runAuthenticated(
        (token) => _api.get('/checkins', token: token),
      );
      final remote = (response['data'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _fromRemote(Map<String, dynamic>.from(value)))
          .toList();
      final remoteDates = remote.map((entry) => _dateOnly(entry.date)).toSet();
      // Older local entries that were created before the queue existed are
      // promoted into it instead of being silently lost after a restart.
      for (final entry in cached.where(
        (entry) => !remoteDates.contains(_dateOnly(entry.date)),
      )) {
        await _queue.enqueue(
          key: _dateOnly(entry.date),
          type: 'checkin',
          payload: {'date': _dateOnly(entry.date), 'scores': entry.scores},
        );
      }
      await _syncPending();
      final refreshed = await auth.runAuthenticated(
        (token) => _api.get('/checkins', token: token),
      );
      final latestRemote = (refreshed['data'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _fromRemote(Map<String, dynamic>.from(value)))
          .toList();
      final merged = _merge(latestRemote, cached);
      final pendingDates = (await _queue.load())
          .where((item) => item.type == 'checkin')
          .map((item) => item.key)
          .toSet();
      for (final entry in cached) {
        if (pendingDates.contains(_dateOnly(entry.date))) {
          final index = merged.indexWhere(
            (value) => _dateOnly(value.date) == _dateOnly(entry.date),
          );
          if (index >= 0) {
            merged[index] = entry;
          } else {
            merged.add(entry);
          }
        }
      }
      await _local.save(merged);
      return merged;
    } catch (error) {
      await _markFailure(error);
      return cached;
    }
  }

  Future<void> saveEntry(CheckinEntry entry, List<CheckinEntry> history) =>
      _serialized(() => _saveEntry(entry, history));

  Future<void> _saveEntry(
    CheckinEntry entry,
    List<CheckinEntry> history,
  ) async {
    await _local.save(history);
    if (!auth.isAuthenticated) return;
    try {
      await _queue.enqueue(
        key: _dateOnly(entry.date),
        type: 'checkin',
        payload: {'date': _dateOnly(entry.date), 'scores': entry.scores},
      );
      await _syncPending();
    } on OfflineSyncQueueCorruptionException catch (error) {
      await _markFailure(error);
    }
  }

  Future<int> syncPending() => _serialized(() async {
    try {
      return await _syncPending();
    } on OfflineSyncQueueCorruptionException catch (error) {
      await _markFailure(error);
      return 0;
    }
  });

  Future<int> _syncPending() async {
    if (!auth.isAuthenticated) return 0;
    var synced = 0;
    final items = await _queue.load();
    for (final item in items.where((item) => item.type == 'checkin')) {
      try {
        await _queue.markSyncing(item.key);
        syncState = OfflineSyncState.syncing;
        final scores = (item.payload['scores'] as List? ?? const [])
            .map((value) => (value as num).toInt())
            .toList();
        await auth.runAuthenticated(
          (token) => _api.put(
            '/checkins/today',
            token: token,
            body: {'date': item.payload['date'], 'scores': scores},
          ),
        );
        await _queue.markSynced(item.key);
        synced++;
      } catch (error) {
        lastSyncError = error.toString();
        syncState = OfflineSyncState.failed;
        await _queue.markFailed(item.key, error);
      }
    }
    final snapshot = await _queue.snapshot();
    pendingCount = snapshot.pendingCount + snapshot.failedCount;
    syncState = snapshot.state == OfflineSyncState.localOnly
        ? (pendingCount == 0
              ? OfflineSyncState.synced
              : OfflineSyncState.pending)
        : snapshot.state;
    if (pendingCount == 0 && snapshot.failedCount == 0) {
      lastSyncError = null;
      syncState = OfflineSyncState.synced;
    }
    return synced;
  }

  Future<void> _markFailure(Object error) async {
    // A failed read of the remote history is not a failed mutation. Keep the
    // durable queue item untouched so a transient GET error does not increase
    // retry counts or mark an unrelated check-in as failed.
    lastSyncError = error.toString();
    syncState = OfflineSyncState.failed;
    final snapshot = await _queue.snapshot();
    pendingCount = snapshot.pendingCount + snapshot.failedCount;
  }

  static CheckinEntry _fromRemote(Map<String, dynamic> json) => CheckinEntry(
    date:
        DateTime.tryParse(json['checkinDate'] as String? ?? '') ??
        DateTime.now(),
    scores: (json['scores'] as List? ?? const [])
        .map((value) => (value as num?)?.round() ?? 2)
        .take(5)
        .toList(),
  );

  static List<CheckinEntry> _merge(
    List<CheckinEntry> remote,
    List<CheckinEntry> local,
  ) {
    final values = <String, CheckinEntry>{};
    for (final entry in local) {
      values[_dateOnly(entry.date)] = entry;
    }
    for (final entry in remote) {
      values[_dateOnly(entry.date)] = entry;
    }
    final result = values.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return result.take(30).toList();
  }

  static String _dateOnly(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
