import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ContentStateCard extends StatelessWidget {
  const ContentStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appStatusColors.pale,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.appStatusColors.dark, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

/// A stable placeholder avoids empty/error flashes while the library loads.
class ContentLoadingCard extends StatelessWidget {
  const ContentLoadingCard({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đang tải bài học',
    child: ExcludeSemantics(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _placeholder(context, width: 54, height: 54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _placeholder(context, height: 14),
                        const SizedBox(height: 10),
                        FractionallySizedBox(
                          widthFactor: .7,
                          child: _placeholder(context, height: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _placeholder(context, height: 6),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _placeholder(
    BuildContext context, {
    double? width,
    required double height,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.appStatusColors.soft.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(12),
    ),
  );
}
