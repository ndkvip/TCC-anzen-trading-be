import 'package:flutter/material.dart';

import '../features/auth/auth_models.dart';
import '../core/theme/app_theme.dart';

class ArticleItem {
  const ArticleItem({
    required this.title,
    required this.category,
    required this.readTime,
    required this.accent,
    required this.icon,
  });
  final String title;
  final String category;
  final String readTime;
  final Color accent;
  final IconData icon;
}

class LessonItem {
  const LessonItem({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.questionCount,
    required this.tier,
    required this.progress,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final String duration;
  final int questionCount;
  final LearningTier tier;
  final double progress;
  final IconData icon;

  factory LessonItem.fromJson(Map<String, dynamic> json) => LessonItem(
    id: json['id'] as String? ?? json['slug'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    duration: '${(json['durationMinutes'] as num?)?.toInt() ?? 10} phút',
    questionCount:
        (json['questionCount'] as num?)?.toInt() ??
        ((json['questions'] as List?)?.length ?? 0),
    tier: json['tier'] == 'ADVANCED'
        ? LearningTier.advanced
        : LearningTier.basic,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    icon: json['tier'] == 'ADVANCED'
        ? Icons.multiline_chart_rounded
        : Icons.auto_stories_rounded,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'durationMinutes': int.tryParse(duration.split(' ').first) ?? 10,
    'questionCount': questionCount,
    'tier': tier == LearningTier.advanced ? 'ADVANCED' : 'BASIC',
    'progress': progress,
  };
}

class KnowledgeCard {
  const KnowledgeCard({
    required this.tag,
    required this.title,
    required this.body,
    this.bullets = const [],
    this.imageLabel,
    this.imagePath,
  });

  final String tag;
  final String title;
  final String body;
  final List<String> bullets;
  final String? imageLabel;
  final String? imagePath;
  factory KnowledgeCard.fromJson(Map<String, dynamic> json) => KnowledgeCard(
    tag: json['tag'] as String? ?? 'KIẾN THỨC',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    bullets: (json['bullets'] as List? ?? const [])
        .whereType<String>()
        .toList(),
    imageLabel: json['imageLabel'] as String? ?? json['imageUrl'] as String?,
    imagePath: json['imagePath'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'tag': tag,
    'title': title,
    'body': body,
    'bullets': bullets,
    if (imageLabel != null) 'imageLabel': imageLabel,
    if (imagePath != null) 'imagePath': imagePath,
  };
}

class QuizOption {
  const QuizOption({this.text, this.imageLabel, this.imagePath})
    : assert(text != null || imageLabel != null || imagePath != null);

  final String? text;
  final String? imageLabel;
  final String? imagePath;
  factory QuizOption.fromJson(Map<String, dynamic> json) => QuizOption(
    text: json['text'] as String?,
    imageLabel: json['imageLabel'] as String? ?? json['imageUrl'] as String?,
    imagePath: json['imagePath'] as String?,
  );
  Map<String, dynamic> toJson() => {
    if (text != null) 'text': text,
    if (imageLabel != null) 'imageLabel': imageLabel,
    if (imagePath != null) 'imagePath': imagePath,
  };
}

class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.imageLabel,
    this.imagePath,
  });

  final String question;
  final String? imageLabel;
  final String? imagePath;
  final List<QuizOption> options;
  final int correctIndex;
  final String explanation;
  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    question: json['question'] as String? ?? '',
    options: (json['options'] as List? ?? const [])
        .whereType<Map>()
        .map((v) => QuizOption.fromJson(Map<String, dynamic>.from(v)))
        .toList(),
    correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
    explanation: json['explanation'] as String? ?? '',
    imageLabel: json['imageLabel'] as String? ?? json['imageUrl'] as String?,
    imagePath: json['imagePath'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options.map((v) => v.toJson()).toList(),
    'correctIndex': correctIndex,
    'explanation': explanation,
    if (imageLabel != null) 'imageLabel': imageLabel,
    if (imagePath != null) 'imagePath': imagePath,
  };
}

const knowledgeCards = [
  KnowledgeCard(
    tag: 'NỀN TẢNG 01',
    title: 'Đọc cấu trúc thị trường',
    body:
        'Cấu trúc giúp bạn biết giá đang tiếp tục xu hướng hay bắt đầu chuyển trạng thái. Hãy quan sát các đỉnh và đáy quan trọng thay vì chỉ nhìn một cây nến.',
    bullets: [
      'Xác định đỉnh và đáy gần nhất',
      'Đọc hướng di chuyển của giá',
      'Chờ phá vỡ có xác nhận',
    ],
  ),
  KnowledgeCard(
    tag: 'NỀN TẢNG 02',
    title: 'Vùng cung và vùng cầu',
    body:
        'Vùng giá là bối cảnh để quan sát phản ứng, không phải một điểm vào lệnh chắc chắn. Chất lượng vùng đến từ chuyển động mạnh rời khỏi vùng đó.',
    imageLabel: 'Hình minh họa vùng cung / cầu',
  ),
  KnowledgeCard(
    tag: 'NỀN TẢNG 03',
    title: 'Luôn có điều kiện vô hiệu',
    body:
        'Một ý tưởng giao dịch tốt phải nói rõ khi nào nó không còn đúng. Điều này giúp bạn thoát khỏi giả thuyết thay vì cố gắng bảo vệ một lệnh sai.',
    bullets: [
      'Ghi trước điểm vô hiệu',
      'Xác định rủi ro tối đa',
      'Không dời stop để gỡ lỗ',
    ],
  ),
  KnowledgeCard(
    tag: 'NỀN TẢNG 04',
    title: 'Chờ xác nhận trước khi hành động',
    body:
        'Không cần dự đoán mọi chuyển động. Hãy để giá quay về vùng quan sát, tạo tín hiệu phù hợp rồi mới thực thi theo kế hoạch.',
    imageLabel: 'Chart demo: giá hồi về vùng chờ',
  ),
];

const articles = [
  ArticleItem(
    title: '3 dấu hiệu thị trường đang đổi cấu trúc',
    category: 'Phân tích',
    readTime: '6 phút đọc',
    accent: AppColors.lime,
    icon: Icons.candlestick_chart_rounded,
  ),
  ArticleItem(
    title: 'Cách giữ kỷ luật sau một lệnh thua',
    category: 'Tâm lý',
    readTime: '4 phút đọc',
    accent: AppColors.coral,
    icon: Icons.psychology_alt_rounded,
  ),
  ArticleItem(
    title: 'Bản tin thị trường tuần 34',
    category: 'Bản tin',
    readTime: '8 phút đọc',
    accent: AppColors.blue,
    icon: Icons.newspaper_rounded,
  ),
];

const lessons = [
  LessonItem(
    id: 'market-structure',
    title: 'Cấu trúc thị trường',
    description: 'Nhận diện xu hướng, vùng giá và điểm phá vỡ cấu trúc.',
    duration: '18 phút',
    questionCount: 8,
    tier: LearningTier.basic,
    progress: .72,
    icon: Icons.account_tree_rounded,
  ),
  LessonItem(
    id: 'supply-demand',
    title: 'Supply & Demand',
    description: 'Hiểu cách vùng cung cầu hình thành và phản ứng với giá.',
    duration: '22 phút',
    questionCount: 10,
    tier: LearningTier.basic,
    progress: .28,
    icon: Icons.swap_vert_circle_rounded,
  ),
  LessonItem(
    id: 'risk-management',
    title: 'Quản trị rủi ro',
    description: 'Xây quy tắc vị thế và bảo vệ tài khoản dài hạn.',
    duration: '16 phút',
    questionCount: 6,
    tier: LearningTier.basic,
    progress: 0,
    icon: Icons.shield_outlined,
  ),
  LessonItem(
    id: 'liquidity',
    title: 'Thanh khoản nâng cao',
    description: 'Đọc cụm thanh khoản và hành vi săn stop trên biểu đồ.',
    duration: '28 phút',
    questionCount: 12,
    tier: LearningTier.advanced,
    progress: .08,
    icon: Icons.water_drop_outlined,
  ),
  LessonItem(
    id: 'order-flow',
    title: 'Order Flow thực chiến',
    description: 'Kết hợp dòng lệnh với bối cảnh để lọc điểm vào.',
    duration: '35 phút',
    questionCount: 15,
    tier: LearningTier.advanced,
    progress: 0,
    icon: Icons.multiline_chart_rounded,
  ),
  LessonItem(
    id: 'execution-model',
    title: 'Mô hình thực thi lệnh',
    description:
        'Đọc tín hiệu xác nhận và tối ưu cách thực thi trong vùng giá.',
    duration: '31 phút',
    questionCount: 14,
    tier: LearningTier.advanced,
    progress: 0,
    icon: Icons.bolt_rounded,
  ),
];

const quizQuestions = [
  QuizQuestion(
    question: 'Vùng cầu thường được hình thành khi nào?',
    options: [
      QuizOption(text: 'Giá tích lũy rồi tăng mạnh'),
      QuizOption(text: 'Giá giảm nhẹ trong thời gian ngắn'),
      QuizOption(imageLabel: 'Hình: vùng cầu trên biểu đồ'),
    ],
    correctIndex: 0,
    explanation:
        'Một vùng cầu đáng chú ý thường xuất hiện trước nhịp tăng mạnh, cho thấy lực mua chủ động đã vượt lực bán.',
  ),
  QuizQuestion(
    question: 'Khi giá quay lại vùng cầu, ưu tiên đầu tiên là gì?',
    imageLabel: 'Minh họa giá quay lại vùng cầu',
    options: [
      QuizOption(text: 'Mua ngay không cần xác nhận'),
      QuizOption(text: 'Quan sát phản ứng giá và quản trị rủi ro'),
      QuizOption(text: 'Bỏ stop loss để lệnh có thêm khoảng thở'),
    ],
    correctIndex: 1,
    explanation:
        'Vùng giá chỉ tạo bối cảnh. Phản ứng thực tế và giới hạn rủi ro mới quyết định chất lượng giao dịch.',
  ),
  QuizQuestion(
    question: 'Điểm vô hiệu của một vùng cầu thường nằm ở đâu?',
    options: [
      QuizOption(text: 'Phía trên đỉnh gần nhất'),
      QuizOption(text: 'Đúng giữa vùng'),
      QuizOption(text: 'Phía dưới vùng cầu'),
    ],
    correctIndex: 2,
    explanation:
        'Nếu giá xuyên qua phần đáy vùng cầu, giả thuyết lực mua bảo vệ vùng đó không còn hiệu lực.',
  ),
];
