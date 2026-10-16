import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Keeps the app-wide accent in sync with the signed-in user's latest check-in.
class CheckinThemeController extends ChangeNotifier {
  String _accountId = 'guest';
  double? _score;

  String get accountId => _accountId;
  double? get score => _score;

  Color get accent =>
      _score == null ? AppColors.green : scoreStatus(_score!).color;

  String get statusLabel =>
      _score == null ? 'Chưa điểm danh' : scoreStatus(_score!).label;

  void setScore({required String accountId, required double? score}) {
    final normalizedAccountId = accountId.trim().isEmpty ? 'guest' : accountId;
    final normalizedScore = score?.clamp(0, 10).toDouble();
    if (_accountId == normalizedAccountId && _score == normalizedScore) return;
    _accountId = normalizedAccountId;
    _score = normalizedScore;
    notifyListeners();
  }

  void clear({String accountId = 'guest'}) =>
      setScore(accountId: accountId, score: null);
}

class ScoreStatus {
  const ScoreStatus({
    required this.label,
    required this.warning,
    required this.color,
  });

  final String label;
  final String warning;
  final Color color;
}

ScoreStatus scoreStatus(double score) {
  if (score < 4) {
    return const ScoreStatus(
      label: 'Mức thấp',
      warning: 'Hạn chế giao dịch, ưu tiên nghỉ ngơi và quan sát.',
      color: AppColors.red,
    );
  }
  if (score < 7) {
    return const ScoreStatus(
      label: 'Mức trung bình',
      warning: 'Chỉ giao dịch khi tín hiệu rõ và đúng kế hoạch.',
      color: AppColors.orange,
    );
  }
  return const ScoreStatus(
    label: 'Mức cao',
    warning: 'Có thể giao dịch nhưng vẫn giữ đúng kỷ luật.',
    color: AppColors.checkinGreen,
  );
}
