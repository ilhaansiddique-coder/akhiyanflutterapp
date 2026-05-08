import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/notification_bell.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

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
        title: const Text('Staff Accounts'),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.person_add),
        label: const Text('Invite Staff'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md)
            .copyWith(bottom: AppSpacing.xl + AppSpacing.lg),
        children: [
          for (final s in const [
            ('Stitch Henderson', 'Super Admin', 'Online', AppColors.success),
            ('Shuvro Khan', 'Order Manager', 'Online', AppColors.success),
            ('Rifat Hasan', 'Inventory Lead', 'Away', AppColors.warning),
            ('Mehedi Talukder', 'Customer Support', 'Offline',
                AppColors.outline),
            ('Sara Ahmed', 'Marketing', 'Offline', AppColors.outline),
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
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            s.$1.substring(0, 1),
                            style: AppTypography.bodyMd.copyWith(
                              color: AppColors.primaryFixed,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: s.$4,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.surfaceContainerLowest,
                                  width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.$1,
                              style: AppTypography.bodyMd
                                  .copyWith(fontWeight: FontWeight.w700)),
                          Text(s.$2,
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              )),
                        ],
                      ),
                    ),
                    Text(s.$3,
                        style: AppTypography.caption.copyWith(
                          color: s.$4,
                          fontWeight: FontWeight.w600,
                        )),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_vert),
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
