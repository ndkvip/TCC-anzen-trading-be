import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'red_news_model.dart';

class RedNewsSection extends StatelessWidget {
  const RedNewsSection({
    super.key,
    required this.items,
    required this.now,
    required this.lastUpdated,
    required this.isRefreshing,
    required this.onRefresh,
  });
  final List<RedNewsItem> items;
  final DateTime now;
  final DateTime? lastUpdated;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]
      ..sort((a, b) => a.releaseAt.compareTo(b.releaseAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'LỊCH THỊ TRƯỜNG',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.red,
                  letterSpacing: 1.2,
                  fontSize: 10,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatLastUpdated(lastUpdated),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: 'Cập nhật tin quan trọng',
                  onPressed: isRefreshing ? null : () => onRefresh(),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: AnimatedRotation(
                    turns: isRefreshing ? 1 : 0,
                    duration: const Duration(milliseconds: 800),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 19,
                      color: isRefreshing ? AppColors.muted : AppColors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        Text(
          'Tin quan trọng trong tuần',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Tuần này chưa có tin quan trọng nào được cập nhật.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  RedNewsRow(item: sorted[i], now: now),
                  if (i < sorted.length - 1)
                    const Divider(height: 1, indent: 64, endIndent: 16),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  color: AppColors.red.withValues(alpha: .045),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.red,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bạn sẽ được nhắc trước 10 phút và đúng giờ tin công bố.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _formatLastUpdated(DateTime? value) {
  if (value == null) return 'Chưa cập nhật';
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return 'Cập nhật $hour:$minute';
}

class RedNewsRow extends StatelessWidget {
  const RedNewsRow({super.key, required this.item, required this.now});
  final RedNewsItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isPast = !item.releaseAt.isAfter(now);
    final until = item.releaseAt.difference(now);
    final status = isPast
        ? 'Đã phát hành'
        : until.inMinutes < 60
        ? 'Còn ${until.inMinutes.clamp(1, 59)} phút'
        : 'Sắp diễn ra';
    final date =
        '${item.releaseAt.day.toString().padLeft(2, '0')}/${item.releaseAt.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isPast
                  ? AppColors.line
                  : AppColors.red.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.priority_high_rounded,
              color: isPast ? AppColors.muted : AppColors.red,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (item.currency != null)
                      Text(
                        item.currency!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    NewsMeta(
                      icon: Icons.calendar_today_outlined,
                      text: '${_dayLabel(item.releaseAt.weekday)}, $date',
                    ),
                    const SizedBox(width: 8),
                    NewsMeta(
                      icon: Icons.schedule_rounded,
                      text: _formatTime(item.releaseAt),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPast
                                ? AppColors.line
                                : AppColors.red.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isPast ? AppColors.muted : AppColors.red,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  String _dayLabel(int weekday) =>
      const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][weekday - 1];
}

class NewsMeta extends StatelessWidget {
  const NewsMeta({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: AppColors.muted),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
