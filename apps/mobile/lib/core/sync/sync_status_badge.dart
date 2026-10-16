import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'offline_sync.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.snapshot, this.onRetry});

  final OfflineSyncSnapshot snapshot;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (snapshot.state == OfflineSyncState.synced && !snapshot.hasWork) {
      return const SizedBox.shrink();
    }
    final (color, icon) = switch (snapshot.state) {
      OfflineSyncState.localOnly => (AppColors.muted, Icons.phone_android),
      OfflineSyncState.pending => (
        AppColors.orange,
        Icons.cloud_upload_outlined,
      ),
      OfflineSyncState.syncing => (AppColors.blue, Icons.sync_rounded),
      OfflineSyncState.synced => (AppColors.green, Icons.cloud_done_outlined),
      OfflineSyncState.failed => (AppColors.coral, Icons.cloud_off_outlined),
      OfflineSyncState.conflict => (
        AppColors.coral,
        Icons.warning_amber_rounded,
      ),
    };
    final detail = snapshot.lastError == null
        ? snapshot.label
        : '${snapshot.label}: ${snapshot.lastError}';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onRetry != null && snapshot.state != OfflineSyncState.syncing)
            IconButton(
              tooltip: 'Thử đồng bộ lại',
              visualDensity: VisualDensity.compact,
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, color: color, size: 18),
            ),
        ],
      ),
    );
  }
}
