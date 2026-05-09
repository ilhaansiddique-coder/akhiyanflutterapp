import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_shell.dart';
import 'package:akhiyan_admin/src/core/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AppBar shared by every top-level tab in the bottom-nav shell.
///
/// Uniform across Dashboard, Orders, Products, Marketing, More:
/// - `menu` icon leading opens the side drawer
/// - "Akhiyan Admin" title
/// - notifications bell with live unread badge — see [NotificationBell]
/// - `home_outlined` action returning to the dashboard
class AppShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppShellAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
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
        const NotificationBell(),
        IconButton(
          tooltip: 'Home',
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.home_outlined, color: AppColors.primary),
        ),
      ],
    );
  }
}
