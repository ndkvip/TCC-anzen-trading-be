import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import '../../core/sync/offline_sync.dart';
import '../auth/auth_controller.dart';
import 'journal_models.dart';

class JournalRepository {
  JournalRepository({
    required this.auth,
    ApiClient? api,
    Future<Directory> Function()? documentsDirectory,
    ImagePicker? imagePicker,
  }) : _api = api ?? ApiClient(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _imagePicker = imagePicker ?? ImagePicker();

  final AuthController auth;
  final ApiClient _api;
  final Future<Directory> Function() _documentsDirectory;
  final ImagePicker _imagePicker;
  Future<void> _tail = Future.value();
  String? lastSyncError;
  int pendingCount = 0;
  OfflineSyncState syncState = OfflineSyncState.localOnly;
  String get accountId => _account;
  String get _account => auth.user?.id ?? 'guest';

  // Serialize mutations and capture the account before any asynchronous work.
  Future<T> _serial<T>(Future<T> Function(String account) action) {
    final account = _account;
    final result = _tail.then((_) {
      if (_account != account) {
        throw const ApiException('Tài khoản đã thay đổi.');
      }
      return action(account);
    });
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<T> _authenticated<T>(
    String account,
    Future<T> Function(String) action,
  ) {
    if (account == 'guest' || _account != account) {
      throw const ApiException('Tài khoản đã thay đổi.');
    }
    return auth.runAuthenticated((token) {
      if (_account != account) {
        throw const ApiException('Tài khoản đã thay đổi.');
      }
      return action(token);
    });
  }

  Future<File> _file(String account) async {
    final root = await _documentsDirectory();
    final dir = Directory('${root.path}/journal');
    await dir.create(recursive: true);
    return File('${dir.path}/$account.json');
  }

  Future<_JournalCache> _read(String account) async {
    final file = await _file(account);
    if (!await file.exists()) return _JournalCache([], {}, {});
    dynamic raw;
    try {
      raw = jsonDecode(await file.readAsString());
    } on FormatException {
      throw const ApiException(
        'Dữ liệu nhật ký trên máy bị lỗi; bản gốc được giữ nguyên.',
      );
    }
    final rows = raw is List ? raw : (raw as Map)['entries'] as List;
    final pending = raw is Map
        ? Map<String, String>.from(raw['pending'] as Map? ?? {})
        : <String, String>{};
    final failed = raw is Map
        ? Map<String, String>.from(raw['failed'] as Map? ?? {})
        : <String, String>{};
    final entries = <TradeEntry>[];
    for (final value in rows.whereType<Map>()) {
      final json = Map<String, dynamic>.from(value);
      // Upgrade old offline records without identities in place.
      if (json['id'] == null || json['id'].toString().startsWith('local-')) {
        json['id'] = _uuid();
        pending[json['id'] as String] = 'create';
      }
      entries.add(TradeEntry.fromJson(json));
    }
    return _JournalCache(entries, pending, failed);
  }

  Future<void> _write(String account, _JournalCache cache) async {
    if (_account == account) {
      pendingCount = <String>{
        ...cache.pending.keys,
        ...cache.failed.keys,
      }.length;
      syncState = cache.failed.isNotEmpty
          ? OfflineSyncState.failed
          : cache.pending.isNotEmpty
          ? OfflineSyncState.pending
          : OfflineSyncState.synced;
    }
    final file = await _file(account);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'entries': cache.entries.map((entry) => entry.toJson()).toList(),
        'pending': cache.pending,
        'failed': cache.failed,
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<List<TradeEntry>> load() => _serial((account) async {
    final cache = await _read(account);
    for (final failed in cache.failed.entries) {
      cache.pending.putIfAbsent(failed.key, () => failed.value);
    }
    lastSyncError = null;
    syncState = cache.pending.isEmpty
        ? OfflineSyncState.synced
        : OfflineSyncState.syncing;
    await _write(account, cache);
    await _sync(account, cache);
    if (account != 'guest' && _account == account) {
      try {
        final intra = await _authenticated(
          account,
          (token) => _api.get('/journal?mode=INTRA_DAY', token: token),
        );
        final swing = await _authenticated(
          account,
          (token) => _api.get('/journal?mode=SWING', token: token),
        );
        final merged = <String, TradeEntry>{};
        for (final value in [
          ...(intra['data'] as List? ?? const []),
          ...(swing['data'] as List? ?? const []),
        ].whereType<Map>()) {
          final remote = TradeEntry.fromJson(Map<String, dynamic>.from(value));
          if (remote.id == null || cache.pending[remote.id] == 'delete') {
            continue;
          }
          merged[remote.id!] = await _restoreEntryImages(account, remote);
        }
        for (final entry in cache.entries) {
          if ((cache.pending.containsKey(entry.id) ||
                  cache.failed.containsKey(entry.id)) &&
              cache.pending[entry.id] != 'delete') {
            merged[entry.id!] = entry;
          }
        }
        cache.entries = merged.values.toList();
      } catch (error) {
        lastSyncError = error.toString();
        syncState = OfflineSyncState.failed;
        await _write(account, cache);
      }
    }
    await _write(account, cache);
    return List.unmodifiable(cache.entries);
  });

  Future<TradeEntry> create(
    TradeEntry entry, {
    required String mode,
    String? date,
  }) => _serial((account) async {
    final json = entry.toJson(date: date, journalMode: mode)..['id'] = _uuid();
    final saved = TradeEntry.fromJson(json);
    final cache = await _read(account);
    cache.entries.add(saved);
    cache.pending[saved.id!] = 'create';
    cache.failed.remove(saved.id);
    await _write(account, cache);
    await _sync(account, cache);
    return cache.entries.firstWhere((value) => value.id == saved.id);
  });

  Future<TradeEntry> update(TradeEntry entry) => _serial((account) async {
    final cache = await _read(account);
    final index = cache.entries.indexWhere((value) => value.id == entry.id);
    if (entry.id == null || index < 0) {
      throw const ApiException('Nhật ký không tồn tại trên máy.');
    }
    cache.entries[index] = entry;
    cache.pending[entry.id!] = cache.pending[entry.id] == 'create'
        ? 'create'
        : 'update';
    cache.failed.remove(entry.id);
    await _write(account, cache);
    await _sync(account, cache);
    return cache.entries.firstWhere((value) => value.id == entry.id);
  });

  Future<void> deleteEntry(TradeEntry entry) => _serial((account) async {
    if (entry.id == null) return;
    final cache = await _read(account);
    cache.entries.removeWhere((value) => value.id == entry.id);
    // Even an unacknowledged create may already exist on the server.
    cache.pending[entry.id!] = 'delete';
    cache.failed.remove(entry.id);
    await _write(account, cache);
    await _sync(account, cache);
  });

  Future<void> _sync(String account, _JournalCache cache) async {
    lastSyncError = null;
    if (account == 'guest' || _account != account) return;
    syncState = cache.pending.isEmpty
        ? OfflineSyncState.synced
        : OfflineSyncState.syncing;
    for (final mutation in cache.pending.entries.toList()) {
      if (_account != account) return;
      try {
        if (mutation.value == 'delete') {
          if (!mutation.key.startsWith('local-')) {
            try {
              await _authenticated(
                account,
                (token) =>
                    _api.delete('/journal/${mutation.key}', token: token),
              );
            } on ApiException catch (error) {
              if (error.statusCode != 404) rethrow;
            }
          }
        } else {
          final index = cache.entries.indexWhere(
            (entry) => entry.id == mutation.key,
          );
          if (index < 0) continue;
          final entry = cache.entries[index];
          final localImages = {
            ...entry.imageUrls,
            ...journalNoteImages(entry.notesDelta),
          }.toList();
          final remoteImages = await _remoteImages(account, localImages);
          final replacements = Map<String, String>.fromIterables(
            localImages,
            remoteImages,
          );
          final body = entry.toJson()
            ..['processImageUrls'] = remoteImages
            ..['notesDelta'] = replaceJournalNoteImages(
              entry.notesDelta,
              replacements,
            );
          Map<String, dynamic> json;
          if (mutation.value == 'create') {
            final created = await _authenticated(
              account,
              (token) => _api.post('/journal', token: token, body: body),
            );
            // A retry can receive an older idempotent record when the first
            // response was lost. Patch only when the server needs reconciling.
            if (_needsReconcile(created, body)) {
              final patchBody = Map<String, dynamic>.from(body)..remove('id');
              json = await _authenticated(
                account,
                (token) => _api.patch(
                  '/journal/${mutation.key}',
                  token: token,
                  body: patchBody,
                ),
              );
            } else {
              json = created;
            }
          } else {
            final patchBody = Map<String, dynamic>.from(body)..remove('id');
            json = await _authenticated(
              account,
              (token) => _api.patch(
                '/journal/${mutation.key}',
                token: token,
                body: patchBody,
              ),
            );
          }
          // Keep local cache paths for offline rendering while the API stores
          // their Drive URLs. The remote response remains the source of truth
          // for the other fields.
          cache.entries[index] = TradeEntry.fromJson(
            json
              ..['id'] = mutation.key
              ..['processImageUrls'] = localImages
              ..['notesDelta'] = entry.notesDelta,
          );
        }
        cache.pending.remove(mutation.key);
        cache.failed.remove(mutation.key);
        // Persist each acknowledgement so a later failed upload cannot repeat it.
        await _write(account, cache);
      } catch (error) {
        lastSyncError = error.toString();
        syncState = OfflineSyncState.failed;
        cache.failed[mutation.key] = mutation.value;
        await _write(account, cache);
      }
    }
  }

  bool _needsReconcile(
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
  ) {
    if (remote['id'] == null) return true;
    const fields = [
      'symbol',
      'direction',
      'pnl',
      'riskReward',
      'priceMovement',
      'management',
      'holdingHours',
      'timeframePair',
      'tradeDate',
      'mode',
      'entryAt',
      'idea',
      'execution',
      'result',
      'processImageUrls',
      'notesDelta',
    ];
    for (final field in fields) {
      if (field == 'entryAt' && remote[field] != null && local[field] != null) {
        if (DateTime.tryParse(remote[field].toString()) !=
            DateTime.tryParse(local[field].toString())) {
          return true;
        }
      } else if (!_sameValue(remote[field], local[field])) {
        return true;
      }
    }
    return false;
  }

  bool _sameValue(dynamic a, dynamic b) {
    if (a is num && b is num) return a == b;
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(
            a.length,
            (index) => index,
          ).every((index) => _sameValue(a[index], b[index]));
    }
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every(
            (key) => b.containsKey(key) && _sameValue(a[key], b[key]),
          );
    }
    return a == b;
  }

  Future<List<String>> _remoteImages(String account, List<String> paths) async {
    final result = <String>[];
    for (final path in paths) {
      if (Uri.tryParse(path)?.hasScheme == true && !path.startsWith('file:')) {
        result.add(path);
        continue;
      }
      final map = await _readImageMap(account);
      String? remote;
      for (final item in map.entries) {
        if (item.value == path) remote = item.key;
      }
      if (remote == null) {
        final file = File(path);
        if (!await file.exists()) {
          throw const ApiException('Không tìm thấy ảnh trên máy.');
        }
        final uploaded = await _authenticated(
          account,
          (token) => _api.uploadFile(
            '/media/upload',
            file: file,
            token: token,
            fields: {
              'contextType': 'JOURNAL',
              'name': file.uri.pathSegments.last,
              'localReference': path,
            },
          ),
        );
        remote = uploaded['remoteUrl'] as String?;
        if (remote == null || remote.isEmpty) {
          throw const ApiException('Chưa thể tải ảnh lên Google Drive.');
        }
        await _rememberImage(account, remote, path);
      }
      result.add(remote);
    }
    return result;
  }

  Future<File> _imageMapFile(String account) async {
    final root = await _documentsDirectory();
    final dir = Directory('${root.path}/journal/$account');
    await dir.create(recursive: true);
    return File('${dir.path}/image-map.json');
  }

  Future<Map<String, String>> _readImageMap(String account) async {
    try {
      return Map<String, String>.from(
        jsonDecode(await (await _imageMapFile(account)).readAsString()) as Map,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _rememberImage(
    String account,
    String remote,
    String local,
  ) async {
    final map = await _readImageMap(account)
      ..[remote] = local;
    await (await _imageMapFile(
      account,
    )).writeAsString(jsonEncode(map), flush: true);
  }

  Future<TradeEntry> _restoreEntryImages(
    String account,
    TradeEntry entry,
  ) async {
    final allImages = <String>{
      ...entry.imageUrls,
      ...journalNoteImages(entry.notesDelta),
    }.toList();
    final restored = <String>[];
    for (final url in allImages) {
      final cached = (await _readImageMap(account))[url];
      if (cached != null && await File(cached).exists()) {
        restored.add(cached);
        continue;
      }
      try {
        final bytes = await _authenticated(
          account,
          (token) => _api.download(_imageDownloadPath(url), token: token),
        );
        final root = await _documentsDirectory();
        final dir = Directory('${root.path}/journal/$account/media');
        await dir.create(recursive: true);
        final file = File('${dir.path}/drive-${url.hashCode.abs()}.webp');
        await file.writeAsBytes(bytes, flush: true);
        await _rememberImage(account, url, file.path);
        restored.add(file.path);
      } catch (_) {
        restored.add(url);
      }
    }
    final replacements = Map<String, String>.fromIterables(allImages, restored);
    return TradeEntry.fromJson(
      entry.toJson()
        ..['processImageUrls'] = entry.imageUrls
            .map((url) => replacements[url] ?? url)
            .toList()
        ..['notesDelta'] = replaceJournalNoteImages(
          entry.notesDelta,
          replacements,
        ),
    );
  }

  String _imageDownloadPath(String url) {
    final uri = Uri.tryParse(url);
    if (uri?.host == 'drive.google.com') {
      final segments = uri!.pathSegments;
      final id =
          uri.queryParameters['id'] ??
          (segments.length >= 3 && segments[0] == 'file' && segments[1] == 'd'
              ? segments[2]
              : null);
      if (id != null) return '/media/drive-images/${Uri.encodeComponent(id)}';
    }
    return url;
  }

  Future<String?> pickAndStoreImage() async {
    final account = _account;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || _account != account) return null;
    final root = await _documentsDirectory();
    final dir = Directory('${root.path}/journal/$account/media');
    await dir.create(recursive: true);
    final dot = picked.path.lastIndexOf('.');
    final extension = dot >= 0 ? picked.path.substring(dot) : '.jpg';
    return (await File(
      picked.path,
    ).copy('${dir.path}/trade-${_uuid()}$extension')).path;
  }
}

class _JournalCache {
  _JournalCache(this.entries, this.pending, this.failed);
  List<TradeEntry> entries;
  final Map<String, String> pending;
  final Map<String, String> failed;
}

String _uuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
