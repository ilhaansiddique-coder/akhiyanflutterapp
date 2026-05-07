import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/akhiyan_api.dart';
import '../../features/auth/application/auth_controller.dart';
import '../api/api_providers.dart';
import '../router/app_router.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Left side drawer shared by every top-level tab in the bottom-nav shell.
///
/// Hosts the secondary nav items that used to live in the now-removed "More"
/// tab: profile card, feature shortcuts (Inventory, Customers, …), Settings,
/// Help & Support, and Sign out.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final items = <(IconData, String, String)>[
      (Icons.people_outline, 'Users', '/customers'),
      (Icons.local_shipping_outlined, 'Courier Management', '/courier'),
      (Icons.local_offer_outlined, 'Coupons', '/coupons'),
      (Icons.bolt_outlined, 'Flash Sales', '/flash-sales'),
      (Icons.link_outlined, 'Shortlinks', '/shortlinks'),
      (Icons.analytics_outlined, 'Analytics', '/analytics'),
      (Icons.notifications_outlined, 'Notifications', '/notifications'),
      (Icons.security_outlined, 'Fraud & Security', '/fraud-security'),
    ];

    void go(String path) {
      Navigator.of(context).pop();
      context.push(path);
    }

    return Drawer(
      backgroundColor: const Color(0xFFF8F9FC),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (session != null) _ProfileCard(session: session, ref: ref),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    ListTile(
                      leading: Icon(items[i].$1, color: AppColors.primary),
                      title: Text(items[i].$2, style: AppTypography.bodyMd),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.onSurfaceVariant),
                      onTap: () => go(items[i].$3),
                    ),
                    if (i < items.length - 1)
                      const Divider(
                          height: 1,
                          indent: 56,
                          color: AppColors.outlineVariant),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_outlined,
                        color: AppColors.onSurfaceVariant),
                    title: Text('Settings', style: AppTypography.bodyMd),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.onSurfaceVariant),
                    onTap: () {},
                  ),
                  const Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.outlineVariant),
                  ListTile(
                    leading: const Icon(Icons.help_outline,
                        color: AppColors.onSurfaceVariant),
                    title: Text('Help & Support', style: AppTypography.bodyMd),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.onSurfaceVariant),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authControllerProvider.notifier).logout();
                context.go(AppRoute.login.path);
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: Text('Sign out',
                  style:
                      AppTypography.bodyMd.copyWith(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile card at the top of the drawer.
///
/// Falls back to the cached [AuthSession] (name + role from login) immediately
/// for snappy first paint, then upgrades to the full [AdminUser] (with email,
/// phone, avatar) once `/auth/me` resolves.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session, required this.ref});
  final AuthSession session;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final asyncUser = ref.watch(currentUserProvider);
    final user = asyncUser.value;

    final name = user?.name.isNotEmpty == true ? user!.name : session.userName;
    final role = (user?.role ?? session.userRole).toUpperCase();
    final email = user?.email;
    final initials = _initials(name);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primaryFixed,
            backgroundImage: (user?.avatar != null && user!.avatar!.isNotEmpty)
                ? NetworkImage(user.avatar!)
                : null,
            child: (user?.avatar == null || user!.avatar!.isEmpty)
                ? Text(
                    initials,
                    style: AppTypography.h3.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.h3.copyWith(
                    fontSize: 16,
                    color: AppColors.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email != null && email.isNotEmpty)
                  Text(
                    email,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onPrimaryContainer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      role,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (asyncUser.isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
