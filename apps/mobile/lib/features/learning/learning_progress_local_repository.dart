import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LearningProgressLocalRepository {
  LearningProgressLocalRepository({
    Future<Directory> Function()? documentsDirectory,
    String accountId = 'guest',
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _accountId = _safeAccountId(accountId);

  final Future<Directory> Function() _documentsDirectory;
  final String _accountId;

  Future<Map<String, double>> load() async {
    final file = await _progressFile();
    if (!await file.exists()) return {};

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map(
        (lessonId, value) => MapEntry(
          lessonId,
          ((value as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
        ),
      );
    } on FormatException {
      return {};
    } on IOException {
      return {};
    }
  }

  Future<void> save(String lessonId, double progress) async {
    final values = await load();
    final current = values[lessonId] ?? 0;
    if (progress <= current) return;

    values[lessonId] = progress.clamp(0.0, 1.0);
    final file = await _progressFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(values), flush: true);
    await temporary.rename(file.path);
  }

  Future<File> _progressFile() async {
    final root = await _documentsDirectory();
    return File('${root.path}/learning/$_accountId/progress.json');
  }

  static String _safeAccountId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 'guest';
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }
}
