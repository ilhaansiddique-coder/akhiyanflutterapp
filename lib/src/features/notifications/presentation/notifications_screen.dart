import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_store.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_drawer.dart';

/// Live notification panel — wired to [notificationStoreProvider] which is
/// fed by the SSE stream. Each backend `bumpVersion(channel, notify)` with
/// a `notify` payload appears here as a card; the bell icon in
/// [AppShellAppBar] shows the unread count concurrently.
///
/// Tapping a notification with an `href` deep-links to that route AND marks
/// it read. Cards without an href are still markable — tap moves them to
/// the read state without navigating.
///
/// Note: this is in-memory only. Quitting the app clears the panel — see
/// the doc comment in [NotificationStore] for the rationale + the path to
/// adding Hive persistence later if needed.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationStoreProvider);
    final entries = state.entries;
    final hasUnread = state.unreadCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ),
        title: const Text('Notifications'),
        actions: [
          TextButton(
            // Disabled when nothing's unread — prevents accidental no-op.
            onPressed: hasUnread
                ? () => ref.read(notificationStoreProvider.notifier).markAllRead()
                : null,
            child: const Text('Mark all read'),
          ),
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: entries.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: entries.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _NotificationCard(entry: entries[i]),
              ),
            ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.entry});

  final NotificationEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = !entry.read;
    final accent = _accentForSeverity(entry.severity);

    void onTap() {
      ref.read(notificationStoreProvider.notifier).markRead(entry.id);
      final href = entry.href;
      if (href != null && href.isNotEmpty) context.push(href);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: unread
              ? accent.tint.withValues(alpha: 0.12)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(
            color: unread ? accent.border : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: unread ? accent.iconBg : AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(
                entry.iconData,
                size: 18,
                color: unread ? accent.iconFg : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _relativeTime(entry.receivedAt),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.body,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 56,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'You\'re all caught up',
              style: AppTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'New orders, status changes, and admin events will appear here as they happen.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityAccent {
  const _SeverityAccent({
    required this.tint,
    required this.border,
    required this.iconBg,
    required this.iconFg,
  });
  final Color tint;
  final Color border;
  final Color iconBg;
  final Color iconFg;
}

_SeverityAccent _accentForSeverity(NotifySeverity s) {
  switch (s) {
    case NotifySeverity.alert:
      return _SeverityAccent(
        tint: AppColors.error,
        border: AppColors.error.withValues(alpha: 0.5),
        iconBg: AppColors.errorContainer,
        iconFg: AppColors.error,
      );
    case NotifySeverity.warn:
      return _SeverityAccent(
        tint: AppColors.warning,
        border: AppColors.warning.withValues(alpha: 0.5),
        iconBg: AppColors.warningContainer,
        iconFg: AppColors.warning,
      );
    case NotifySeverity.info:
      return const _SeverityAccent(
        tint: AppColors.primary,
        border: AppColors.primaryFixed,
        iconBg: AppColors.primaryFixed,
        iconFg: AppColors.primary,
      );
  }
}

/// Compact "2m / 1h / Yesterday / Mar 12" formatter — keeps the right-side
/// timestamp in the card legible without dragging in `intl`.
String _relativeTime(DateTime at) {
  final delta = DateTime.now().difference(at);
  if (delta.inSeconds < 60) return 'now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (delta.inHours < 24) return '${delta.inHours}h';
  if (delta.inDays == 1) return 'Yesterday';
  if (delta.inDays < 7) return '${delta.inDays}d';
  // Fallback: `M DD` (no year — older items rarely show in a 200-cap list)
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[at.month - 1]} ${at.day}';
}
