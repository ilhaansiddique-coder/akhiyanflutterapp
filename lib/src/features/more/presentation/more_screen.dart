import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_shell_app_bar.dart';
import '../../auth/application/auth_controller.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final items = <(IconData, String, String)>[
      (Icons.inventory, 'Inventory', '/inventory'),
      (Icons.people_outline, 'Customers', '/customers'),
      (Icons.local_shipping_outlined, 'Courier Management', '/courier'),
      (Icons.local_offer_outlined, 'Coupons', '/coupons'),
      (Icons.bolt_outlined, 'Flash Sales', '/flash-sales'),
      (Icons.link_outlined, 'Shortlinks', '/shortlinks'),
      (Icons.analytics_outlined, 'Analytics', '/analytics'),
      (Icons.notifications_outlined, 'Notifications', '/notifications'),
      (Icons.security_outlined, 'Fraud & Security', '/fraud-security'),
      (Icons.group_outlined, 'Staff Accounts', '/staff'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: const AppShellAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (session != null) _ProfileCard(session: session),
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
                    onTap: () => context.push(items[i].$3),
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
              ref.read(authControllerProvider.notifier).logout();
              context.go(AppRoute.login.path);
            },
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: Text('Sign out',
                style: AppTypography.bodyMd.copyWith(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session});
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryFixed,
            child: Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.userName,
                    style: AppTypography.h3.copyWith(
                      fontSize: 16,
                      color: AppColors.onPrimaryContainer,
                    )),
                Text(session.userRole,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onPrimaryContainer,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
