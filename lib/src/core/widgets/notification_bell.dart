import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../notifications/notification_store.dart';
import '../theme/colors.dart';

/// Reusable notifications bell with a live unread badge. Drop into any
/// `AppBar.actions` so every screen exposes the same notification entry
/// point. The badge auto-hides when there's nothing unread (avoids drawing
/// a hollow ring on a fresh session) and caps at "9+" so a noisy day
/// doesn't blow out the AppBar layout.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.error,
        textColor: AppColors.onError,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: const Icon(
          Icons.notifications_outlined,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
