import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// AppBar shared by every top-level tab in the bottom-nav shell.
///
/// Uniform across Dashboard, Orders, Products, Marketing, More:
/// - `menu` icon leading (placeholder for a future drawer)
/// - "Akhiyan Admin" title
/// - `notifications_outlined` action that routes to `/notifications`
///
/// If a tab needs something different (e.g., a screen-specific action),
/// it should compose its own `AppBar` rather than parameterising this —
/// the whole point of this widget is that all five tabs look identical.
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
        onPressed: () {},
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
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
