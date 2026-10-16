import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'personal_models.dart';

class CheckinLocalRepository {
  CheckinLocalRepository({
    Future<Directory> Function()? documentsDirectory,
    String accountId = 'guest',
  }) : _documentsDirectory = documentsDirectory,
       _accountId = _safeAccountId(accountId);

  final Future<Directory> Function()? _documentsDirectory;
  final String _accountId;

  Future<Directory> _getDocumentsDirectory() async =>
      _documentsDirectory?.call() ?? getApplicationDocumentsDirectory();

  Future<File> _file() async {
    final root = await _getDocumentsDirectory();
    if (!root.existsSync()) await root.create(recursive: true);
    return File('${root.path}/checkin_history_$_accountId.json');
  }

  Future<List<CheckinEntry>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      final entries = decoded
          .whereType<Map>()
          .map((item) => CheckinEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries.take(30).toList();
    } on FormatException {
      return [];
    } on IOException {
      return [];
    }
  }

  static String _safeAccountId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 'guest';
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  Future<void> save(List<CheckinEntry> entries) async {
    final snapshot = [...entries]..sort((a, b) => b.date.compareTo(a.date));
    final file = await _file();
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert(snapshot.take(30).map((entry) => entry.toJson()).toList());
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(encoded, flush: true);
    await temporary.rename(file.path);
  }
}
