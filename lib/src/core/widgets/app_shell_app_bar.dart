import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../notifications/notification_store.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'app_shell.dart';

/// AppBar shared by every top-level tab in the bottom-nav shell.
///
/// Uniform across Dashboard, Orders, Products, Marketing, More:
/// - `menu` icon leading opens the side drawer
/// - "Akhiyan Admin" title
/// - notifications bell with live unread badge driven by
///   [unreadNotificationsProvider] — the count updates in real time as the
///   SSE stream pushes new orders / status changes / product creates etc.
/// - `home_outlined` action returning to the dashboard
class AppShellAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppShellAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    return AppBar(
      backgroundColor: AppColors.surfaceContainerLowest,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        // Use the shell's Scaffold key — feature screens have their own inner
        // Scaffold, so `Scaffold.of(context)` here would miss the outer drawer.
        onPressed: () => appShellScaffoldKey.currentState?.openDrawer(),
        icon: const Icon(Icons.menu, color: AppColors.primary),
      ),
      title: Text(
        'Akhiyan Admin',
        style: AppTypography.h3.copyWith(
          color: AppColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          // Wrap the icon in a Badge that hides itself when unread == 0, so
          // we don't draw a hollow ring on a fresh, never-fired session.
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.error,
            textColor: AppColors.onError,
            // Cap the visible label at 9+ so a noisy day doesn't blow out
            // the AppBar layout.
            label: Text(unread > 9 ? '9+' : '$unread'),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppColors.primary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Home',
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(
            Icons.home_outlined,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
