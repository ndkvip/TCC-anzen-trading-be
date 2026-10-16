class RedNewsItem {
  const RedNewsItem({
    required this.id,
    required this.title,
    required this.releaseAt,
    this.description,
    this.currency,
    this.isActive = true,
  });

  final String id;
  final String title;
  final DateTime releaseAt;
  final String? description;
  final String? currency;
  final bool isActive;

  factory RedNewsItem.fromJson(Map<String, dynamic> json) => RedNewsItem(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Tin quan trọng',
    releaseAt: DateTime.parse(json['releaseAt'].toString()).toLocal(),
    description: json['description']?.toString(),
    currency: json['currency']?.toString(),
    isActive: json['isActive'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'releaseAt': releaseAt.toIso8601String(),
    'description': description,
    'currency': currency,
    'isActive': isActive,
  };
}
