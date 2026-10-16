import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists a dismissed check-in prompt per account and calendar day.
///
/// The check-in itself is still the source of truth for whether a user has
/// completed the day. This separate marker only prevents a dismissed modal
/// from interrupting the same account again until the next local day.
class CheckinPromptRepository {
  CheckinPromptRepository({
    required this.accountId,
    this.documentsDirectory = getApplicationDocumentsDirectory,
  });

  final String accountId;
  final Future<Directory> Function() documentsDirectory;

  Future<bool> wasDismissed(DateTime date) async {
    final file = await _file();
    if (!await file.exists()) return false;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map && decoded['date'] == _dateOnly(date);
    } on FormatException {
      return false;
    } on IOException {
      return false;
    }
  }

  Future<void> dismiss(DateTime date) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'date': _dateOnly(date)}),
      flush: true,
    );
  }

  Future<File> _file() async {
    final directory = await documentsDirectory();
    final safeId = accountId.trim().isEmpty
        ? 'guest'
        : accountId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${directory.path}/checkin_prompt_$safeId.json');
  }

  static String _dateOnly(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
