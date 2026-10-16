import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import '../../core/sync/offline_sync.dart';
import '../auth/auth_controller.dart';
import 'plan_document.dart';

/// Local-first repository: every edit is persisted on-device first, then synced
/// to the authenticated account when the API is reachable.
class PlanLocalRepository {
  PlanLocalRepository({
    Future<Directory> Function()? documentsDirectory,
    ImagePicker? imagePicker,
    this.auth,
    ApiClient? api,
    String? accountId,
  }) : _documentsDirectory = documentsDirectory,
       _imagePicker = imagePicker ?? ImagePicker(),
       _api = api ?? ApiClient(),
       _accountId = _safeAccountId(accountId ?? auth?.user?.id ?? 'guest') {
    _syncQueue = OfflineSyncQueue(
      accountId: _accountId,
      documentsDirectory: _getDocumentsDirectory,
    );
  }

  final Future<Directory> Function()? _documentsDirectory;
  final ImagePicker _imagePicker;
  final ApiClient _api;
  final AuthController? auth;
  final String _accountId;
  late final OfflineSyncQueue _syncQueue;
  Future<void> _tail = Future<void>.value();
  String? lastSyncError;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<Directory> _getDocumentsDirectory() async =>
      _documentsDirectory?.call() ?? getApplicationDocumentsDirectory();

  Future<Directory> _accountDirectory() async {
    final root = await _getDocumentsDirectory();
    final directory = Directory('${root.path}/plans/$_accountId');
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _mediaDirectory() async {
    final account = await _accountDirectory();
    final media = Directory('${account.path}/media');
    await media.create(recursive: true);
    return media;
  }

  Future<File> _documentFile() async {
    final account = await _accountDirectory();
    return File('${account.path}/offline_plan.json');
  }

  Future<File> _scopedDocumentFile(String scope, DateTime date) async {
    final account = await _accountDirectory();
    final directory = Directory('${account.path}/documents');
    await directory.create(recursive: true);
    return File('${directory.path}/${_storageKey(scope, date)}.json');
  }

  Future<PlanDocument?> _readFile(File file) async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        return PlanDocument.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      // Corrupt cache is treated as missing.
    } on IOException {
      // Offline storage failure falls back to a fresh document.
    }
    return null;
  }

  Future<PlanDocument> load() => _serialized(_load);

  Future<PlanDocument> _load() async {
    final file = await _documentFile();
    return await _readFile(file) ?? PlanDocument.defaultDocument();
  }

  Future<bool> _isDeletePending(String scope, DateTime date) async {
    final key = _periodKey(scope, date);
    final items = await _syncQueue.load();
    return items.any(
      (item) =>
          item.type == 'plan_delete' &&
          _apiScope(item.payload['scope'] as String? ?? '') ==
              _apiScope(scope) &&
          item.payload['periodKey'] == key,
    );
  }

  Future<PlanDocument> loadFor({
    required String scope,
    required DateTime date,
  }) => _serialized(() => _loadFor(scope: scope, date: date));

  Future<PlanDocument> _loadFor({
    required String scope,
    required DateTime date,
  }) async {
    final scoped = await _scopedDocumentFile(scope, date);
    final local = await _readFile(scoped);
    bool deletePending;
    try {
      deletePending = await _isDeletePending(scope, date);
      lastSyncError = null;
    } on OfflineSyncQueueCorruptionException catch (error) {
      lastSyncError = error.toString();
      return (local ?? PlanDocument.emptyFor(scope: scope, date: date))
        ..syncState = PlanSyncState.failed
        ..syncError = lastSyncError;
    }
    if (deletePending) {
      // A local delete must win over a still-visible server copy until the
      // tombstone is acknowledged.
      return PlanDocument.emptyFor(scope: scope, date: date);
    }
    if (_isLocalDirty(local)) {
      final controller = auth;
      if (controller?.isAuthenticated == true) {
        try {
          return await _syncRemote(local!);
        } catch (_) {
          return local!;
        }
      }
      return local!;
    }

    final controller = auth;
    if (controller?.isAuthenticated == true) {
      try {
        final remote = await controller!.runAuthenticated(
          (token) => _api.get(
            '/plans/resolve?scope=${_apiScope(scope)}&periodKey=${_periodKey(scope, date)}',
            token: token,
          ),
        );
        final document = _fromRemote(remote, fallbackScope: scope, date: date);
        // Keep a local copy of Drive images so the plan remains usable offline.
        await _cacheRemoteImages(document);
        // A server draft may contain inherited content. Cache it so inheritance
        // remains available without a connection on the next launch.
        await _writeLocal(document, synced: true);
        return document;
      } catch (_) {
        // Local data remains authoritative while offline.
      }
    }

    if (local != null) return local;

    // Keep the inheritance chain useful offline too. A new day first takes
    // the week's content; if that week has not been saved yet, the month is
    // the effective source through the virtual week.
    final inherited = await _loadLocalInherited(scope, date);
    if (inherited != null) {
      return PlanDocument.emptyFor(scope: scope, date: date)
        ..contentDelta = inherited.editorDelta
        ..timeframePairs = [...inherited.timeframePairs]
        ..inheritedPlanId = inherited.id
        ..inheritedFrom = inherited.title;
    }

    // Migrate the previous single-plan file for this account and period.
    final legacy = await _readFile(await _documentFile());
    if (legacy != null &&
        legacy.scope == scope &&
        _storageKey(legacy.scope, legacy.date) == _storageKey(scope, date)) {
      await _writeLocal(legacy, synced: false);
      return legacy;
    }
    return PlanDocument.emptyFor(scope: scope, date: date);
  }

  Future<File> _imageMapFile() async {
    final account = await _accountDirectory();
    return File('${account.path}/media-map.json');
  }

  Future<void> _rememberImage(String remote, String local) async {
    final file = await _imageMapFile();
    Map<String, dynamic> map = {};
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map) map = Map<String, dynamic>.from(raw);
    } catch (_) {}
    map[remote] = local;
    await file.writeAsString(jsonEncode(map), flush: true);
  }

  Future<String?> _remoteForLocal(String local) async {
    try {
      final raw = jsonDecode(await (await _imageMapFile()).readAsString());
      if (raw is Map) {
        for (final item in raw.entries) {
          if (item.value == local) return item.key.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String> _cacheRemoteImage(String url) async {
    final media = await _mediaDirectory();
    final key = sha256.convert(utf8.encode(url));
    final local = File('${media.path}/drive-$key.webp');
    try {
      if (!await local.exists() || await local.length() == 0) {
        final uri = Uri.tryParse(url);
        final driveId =
            uri != null &&
                (uri.host == 'drive.google.com' ||
                    uri.host == 'docs.google.com')
            ? uri.queryParameters['id'] ??
                  RegExp(r'/file/d/([^/]+)').firstMatch(uri.path)?.group(1)
            : null;
        final endpoint = driveId == null
            ? url
            : '/media/drive-images/${Uri.encodeComponent(driveId)}';
        final controller = auth;
        final bytes = controller?.isAuthenticated == true
            ? await controller!.runAuthenticated(
                (token) => _api.download(endpoint, token: token),
              )
            : await _api.download(endpoint);
        if (bytes.isEmpty) throw const FormatException('Empty plan image');
        final temporary = File('${local.path}.part');
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(local.path);
      }
      await _rememberImage(url, local.path);
      return local.path;
    } catch (_) {
      return url;
    }
  }

  Future<void> _cacheRemoteImages(PlanDocument document) async {
    final delta = <dynamic>[];
    for (final operation in document.editorDelta) {
      if (operation is Map && operation['insert'] is Map) {
        final next = Map<String, dynamic>.from(operation);
        final insert = Map<String, dynamic>.from(operation['insert'] as Map);
        final image = insert['image'];
        if (image is String &&
            (image.startsWith('http://') || image.startsWith('https://'))) {
          insert['image'] = await _cacheRemoteImage(image);
          next['insert'] = insert;
        }
        delta.add(next);
      } else {
        delta.add(operation);
      }
    }
    document.contentDelta = delta;
  }

  Future<PlanDocument?> _loadLocalInherited(String scope, DateTime date) async {
    if (scope == 'Tháng') return null;
    if (scope == 'Tuần') {
      return _readFile(await _scopedDocumentFile('Tháng', date));
    }
    final week = await _readFile(await _scopedDocumentFile('Tuần', date));
    if (week != null) return week;
    return _readFile(await _scopedDocumentFile('Tháng', date));
  }

  Future<String?> _uploadLocalImage(String path) async {
    final file = File(path);
    final controller = auth;
    if (!await file.exists() || controller?.isAuthenticated != true) {
      return null;
    }
    try {
      final cachedRemote = await _remoteForLocal(path);
      if (cachedRemote != null) return cachedRemote;
      final result = await controller!.runAuthenticated(
        (token) => _api.uploadFile(
          '/media/upload',
          file: file,
          token: token,
          fields: {
            'contextType': 'PLAN',
            'name': file.uri.pathSegments.last,
            'localReference': path,
          },
        ),
      );
      final remote = result['remoteUrl'] as String?;
      if (remote != null && remote.isNotEmpty) {
        await _rememberImage(remote, path);
      }
      return remote;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> _remoteDelta(List<dynamic> delta) async {
    final result = <dynamic>[];
    for (final operation in delta) {
      if (operation is! Map || operation['insert'] is! Map) {
        result.add(operation);
        continue;
      }
      final insert = Map<String, dynamic>.from(operation['insert'] as Map);
      final image = insert['image'];
      if (image is String &&
          !image.startsWith('http://') &&
          !image.startsWith('https://')) {
        final remote = await _uploadLocalImage(image);
        if (remote == null) {
          throw const ApiException(
            'Chưa thể đồng bộ hình ảnh lên Google Drive',
          );
        }
        insert['image'] = remote;
        result.add({...Map<String, dynamic>.from(operation), 'insert': insert});
      } else {
        result.add(operation);
      }
    }
    return result;
  }

  Future<void> save(PlanDocument document) =>
      _serialized(() => _save(document));

  Future<void> _save(PlanDocument document) async {
    document.syncState = PlanSyncState.pendingSync;
    document.syncError = null;
    await _writeLocal(document, synced: false);

    final controller = auth;
    if (controller?.isAuthenticated != true) return;
    try {
      document.syncState = PlanSyncState.syncing;
      await _syncRemote(document);
    } catch (error) {
      document.syncState = PlanSyncState.failed;
      document.syncRetryCount += 1;
      document.syncError = error.toString();
      await _writeLocal(document, synced: false);
    }
  }

  Future<PlanDocument> _syncRemote(PlanDocument document) async {
    final controller = auth;
    if (controller?.isAuthenticated != true) {
      throw const ApiException('Chưa đăng nhập để đồng bộ kế hoạch');
    }
    final remoteDelta = await _remoteDelta(document.editorDelta);
    final response = await controller!.runAuthenticated(
      (token) => _api.put(
        '/plans',
        token: token,
        body: {
          'scope': _apiScope(document.scope),
          'periodKey': _periodKey(document.scope, document.date),
          'title': document.title,
          'status': _apiStatus(document.status),
          'contentDelta': remoteDelta,
          'timeframePairs': document.timeframePairs,
          'imageUrls': _imageReferences(remoteDelta),
        },
      ),
    );
    final synced = _fromRemote(
      response,
      fallbackScope: document.scope,
      date: document.date,
    );
    await _cacheRemoteImages(synced);
    await _writeLocal(synced, synced: true);
    document.updatedAt = synced.updatedAt;
    document.id = synced.id;
    document.syncState = PlanSyncState.synced;
    document.syncError = null;
    document.syncRetryCount = 0;
    document.lastSyncedAt = DateTime.now();
    document.status = synced.status;
    document.inheritedPlanId = synced.inheritedPlanId;
    document.inheritedFrom = synced.inheritedFrom;
    await _writeLocal(document, synced: true);
    return synced;
  }

  /// Retries all offline edits when the account becomes online again.
  Future<int> syncPending() => _serialized(() async {
    try {
      final count = await _syncPending();
      lastSyncError = null;
      return count;
    } on OfflineSyncQueueCorruptionException catch (error) {
      lastSyncError = error.toString();
      return 0;
    }
  });

  Future<int> _syncPending() async {
    if (auth?.isAuthenticated != true) return 0;
    var syncedCount = 0;
    final queue = _syncQueue;
    final queuedDeletes = await queue.load();
    for (final item in queuedDeletes.where(
      (item) => item.type == 'plan_delete',
    )) {
      try {
        await queue.markSyncing(item.key);
        var remoteId = item.payload['id'] as String?;
        if (remoteId == null || remoteId.isEmpty) {
          // The first PUT may have succeeded even when its response was lost.
          final remote = await auth!.runAuthenticated(
            (token) => _api.get(
              '/plans/resolve?scope=${_apiScope(item.payload['scope'] as String? ?? '')}&periodKey=${item.payload['periodKey']}',
              token: token,
            ),
          );
          remoteId = remote['id'] as String?;
          if (remoteId == null || remoteId.startsWith('draft-')) {
            await queue.markSynced(item.key);
            continue;
          }
        }
        try {
          await auth!.runAuthenticated(
            (token) => _api.delete('/plans/$remoteId', token: token),
          );
        } on ApiException catch (error) {
          if (error.statusCode != 404) rethrow;
        }
        await queue.markSynced(item.key);
        syncedCount++;
      } catch (error) {
        await queue.markFailed(item.key, error);
      }
    }

    final directory = await _accountDirectory();
    final documents = Directory('${directory.path}/documents');
    if (!await documents.exists()) return syncedCount;
    await for (final entity in documents.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final document = await _readFile(entity);
      if (document == null || !_isLocalDirty(document)) {
        continue;
      }
      try {
        await _syncRemote(document);
        syncedCount++;
      } catch (error) {
        document.syncState = PlanSyncState.failed;
        document.syncRetryCount += 1;
        document.syncError = error.toString();
        await _writeLocal(document, synced: false);
      }
    }
    return syncedCount;
  }

  Future<List<PlanDocument>> list({String? scope}) =>
      _serialized(() => _list(scope: scope));

  Future<List<PlanDocument>> _list({String? scope}) async {
    final byKey = <String, PlanDocument>{};
    final directory = Directory(
      '${(await _accountDirectory()).path}/documents',
    );
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final document = await _readFile(entity);
        if (document == null || (scope != null && document.scope != scope)) {
          continue;
        }
        byKey[_storageKey(document.scope, document.date)] = document;
      }
    }
    final controller = auth;
    final deleteKeys = <String>{};
    List<OfflineSyncItem> queued;
    try {
      queued = await _syncQueue.load();
    } on OfflineSyncQueueCorruptionException catch (error) {
      lastSyncError = error.toString();
      return byKey.values.toList();
    }
    for (final item in queued) {
      if (item.type != 'plan_delete') continue;
      final scopeValue = item.payload['scope'];
      final periodKey = item.payload['periodKey'];
      if (scopeValue is String && periodKey is String) {
        deleteKeys.add('${_apiScope(scopeValue)}:$periodKey');
      }
    }
    if (controller?.isAuthenticated == true) {
      try {
        final remote = await controller!.runAuthenticated(
          (token) => _api.get(
            '/plans${scope == null ? '' : '?scope=${_apiScope(scope)}'}',
            token: token,
          ),
        );
        final values = remote['data'] is List
            ? remote['data'] as List
            : const <dynamic>[];
        for (final value in values.whereType<Map>()) {
          final document = _fromRemote(
            Map<String, dynamic>.from(value),
            fallbackScope: scope ?? 'Ngày',
            date: DateTime.now(),
          );
          final key = _storageKey(document.scope, document.date);
          final deleteKey =
              '${_apiScope(document.scope)}:${_periodKey(document.scope, document.date)}';
          if (!deleteKeys.contains(deleteKey) && !_isLocalDirty(byKey[key])) {
            byKey[key] = document;
          }
        }
      } catch (_) {
        // The local library remains available offline.
      }
    }
    final result = byKey.values.toList()
      ..sort(
        (a, b) => (b.updatedAt ?? DateTime(1970)).compareTo(
          a.updatedAt ?? DateTime(1970),
        ),
      );
    return result;
  }

  Future<void> delete(PlanDocument document) =>
      _serialized(() => _delete(document));

  Future<void> _delete(PlanDocument document) async {
    final remoteDocument =
        !document.id.startsWith('draft-') && !document.id.startsWith('plan-');
    final needsTombstone = remoteDocument || _isLocalDirty(document);
    if (needsTombstone && auth?.isAuthenticated == true) {
      // Persist intent before removing the only local copy.
      await _syncQueue.enqueue(
        key:
            'plan-delete:${_apiScope(document.scope)}:${_periodKey(document.scope, document.date)}',
        type: 'plan_delete',
        payload: {
          'id': remoteDocument ? document.id : null,
          'scope': _apiScope(document.scope),
          'periodKey': _periodKey(document.scope, document.date),
        },
      );
    }
    final file = await _scopedDocumentFile(document.scope, document.date);
    if (await file.exists()) await file.delete();
    // The legacy file is only a compatibility mirror. Remove it when it points
    // at this period, otherwise an offline load could resurrect the deletion.
    final legacyFile = await _documentFile();
    final legacy = await _readFile(legacyFile);
    if (legacy != null &&
        _storageKey(legacy.scope, legacy.date) ==
            _storageKey(document.scope, document.date)) {
      if (await legacyFile.exists()) await legacyFile.delete();
    }
    if (!needsTombstone) {
      return;
    }
    if (auth?.isAuthenticated != true) return;

    await _syncPending();
  }

  static bool _isLocalDirty(PlanDocument? document) =>
      document != null &&
      document.syncState != PlanSyncState.synced &&
      document.syncState != PlanSyncState.localOnly;

  Future<void> _writeLocal(
    PlanDocument document, {
    required bool synced,
  }) async {
    final snapshot = document.copy()
      ..updatedAt = DateTime.now()
      ..syncState = synced ? PlanSyncState.synced : document.syncState;
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert(snapshot.toJson());
    final scopedFile = await _scopedDocumentFile(snapshot.scope, snapshot.date);
    final temporary = File('${scopedFile.path}.tmp');
    await temporary.writeAsString(encoded, flush: true);
    await temporary.rename(scopedFile.path);
    final legacyFile = await _documentFile();
    final legacyTemporary = File('${legacyFile.path}.tmp');
    await legacyTemporary.writeAsString(encoded, flush: true);
    await legacyTemporary.rename(legacyFile.path);
  }

  Future<String?> pickAndStoreImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) return null;
    final media = await _mediaDirectory();
    final extension = _extensionFor(picked.path);
    final file = File(
      '${media.path}/plan-${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(picked.path).copy(file.path);
    return file.path;
  }

  Future<void> deleteImageIfOwned(String path) async {
    if (path.isEmpty) return;
    final media = await _mediaDirectory();
    final mediaPath = '${media.path}${Platform.pathSeparator}';
    if (!path.startsWith(mediaPath)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  PlanDocument _fromRemote(
    Map<String, dynamic> json, {
    required String fallbackScope,
    required DateTime date,
  }) {
    final scope = _localScope(json['scope'] as String? ?? fallbackScope);
    return PlanDocument(
      id: json['id'] as String? ?? 'draft-${_storageKey(scope, date)}',
      title:
          json['title'] as String? ??
          PlanDocument.emptyFor(scope: scope, date: date).title,
      date: _dateForPeriod(json['periodKey'] as String?, scope, date),
      scope: scope,
      session: 'London session',
      timeframePairs: (json['timeframePairs'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      blocks: [PlanBlock.text('')],
      contentDelta: (json['contentDelta'] as List? ?? const []).toList(),
      status: PlanStatus.fromJson(json['status'] as String?),
      inheritedPlanId: json['inheritedPlanId'] as String?,
      inheritedFrom: json['inheritedFrom'] as String?,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      syncState: PlanSyncState.synced,
    );
  }

  static List<String> _imageReferences(List<dynamic> delta) => delta
      .whereType<Map>()
      .map((operation) => operation['insert'])
      .whereType<Map>()
      .map((insert) => insert['image'])
      .whereType<String>()
      .toList();

  static String _apiScope(String scope) => switch (scope) {
    'Tháng' || 'MONTH' => 'MONTH',
    'Tuần' || 'WEEK' => 'WEEK',
    _ => 'DAY',
  };

  static String _localScope(String scope) => switch (scope) {
    'MONTH' => 'Tháng',
    'WEEK' => 'Tuần',
    _ => 'Ngày',
  };

  static String _apiStatus(PlanStatus status) => switch (status) {
    PlanStatus.completed => 'COMPLETED',
    PlanStatus.draft => 'DRAFT',
  };

  static String _periodKey(String scope, DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (_apiScope(scope) == 'MONTH') {
      return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}';
    }
    if (_apiScope(scope) == 'WEEK') {
      final monday = normalized.subtract(
        Duration(days: normalized.weekday - 1),
      );
      return _dateOnly(monday);
    }
    return _dateOnly(normalized);
  }

  static DateTime _dateForPeriod(String? key, String scope, DateTime fallback) {
    if (key == null) return fallback;
    if (scope == 'Tháng') return DateTime.tryParse('$key-01') ?? fallback;
    return DateTime.tryParse(key) ?? fallback;
  }

  static String _dateOnly(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _extensionFor(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.jpg';
    final extension = path.substring(dot).toLowerCase();
    return extension.length <= 5 ? extension : '.jpg';
  }

  static String _storageKey(String scope, DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return switch (scope) {
      'Tuần' => 'week-${_isoWeekYear(normalized)}-${_isoWeek(normalized)}',
      'Tháng' =>
        'month-${normalized.year}-${normalized.month.toString().padLeft(2, '0')}',
      _ => 'day-${_dateOnly(normalized)}',
    };
  }

  static int _isoWeek(DateTime date) {
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 4);
    return 1 + thursday.difference(firstThursday).inDays ~/ 7;
  }

  static int _isoWeekYear(DateTime date) {
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    return thursday.year;
  }

  static String _safeAccountId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 'guest';
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }
}
