class CheckinEntry {
  CheckinEntry({required this.date, required this.scores});

  factory CheckinEntry.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'];
    final scores = rawScores is List
        ? rawScores
              .map((value) => (value as num?)?.round() ?? 0)
              .map((value) => value.clamp(0, 4))
              .take(5)
              .toList()
        : <int>[];
    while (scores.length < 5) {
      scores.add(2);
    }
    return CheckinEntry(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      scores: scores,
    );
  }

  final DateTime date;
  final List<int> scores;

  double get totalScore => scores.fold<int>(0, (sum, value) => sum + value) / 2;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'scores': scores,
  };
}
