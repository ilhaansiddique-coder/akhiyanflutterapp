import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/notification_bell.dart';

class FraudSecurityScreen extends StatelessWidget {
  const FraudSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Fraud & Security'),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: AppColors.error),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('3 active alerts',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          )),
                      Text('Suspicious login attempts in the last 24h',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onErrorContainer,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Recent Events',
              style: AppTypography.h3.copyWith(fontSize: 18)),
          const SizedBox(height: AppSpacing.sm),
          for (final e in const [
            (Icons.login, 'Suspicious login from Mumbai, IN', '2 min ago',
                AppColors.error),
            (Icons.report_outlined, 'Order #ORD-8821 flagged as suspicious',
                '15 min ago', AppColors.warning),
            (Icons.check_circle_outline, 'Login from Dhaka, BD verified',
                '2h ago', AppColors.success),
            (Icons.password, 'Password changed for staff: Shuvro', 'Yesterday',
                AppColors.onSurfaceVariant),
            (Icons.shield_outlined, '2FA enabled on Super Admin account',
                '2 days ago', AppColors.success),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: e.$4.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Icon(e.$1, size: 20, color: e.$4),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.$2,
                              style: AppTypography.bodySm.copyWith(
                                fontWeight: FontWeight.w600,
                              )),
                          Text(e.$3,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.onSurfaceVariant,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
