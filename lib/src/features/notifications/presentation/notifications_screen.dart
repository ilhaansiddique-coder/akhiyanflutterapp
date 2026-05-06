import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Mark all read')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (final n in const [
            (Icons.shopping_bag, 'New order #ORD-8821', 'Rahat ordered 3 items',
                '2m', true),
            (Icons.warning_amber, 'Low stock alert',
                'Premium ANC Headphones — 3 left', '15m', true),
            (Icons.payments, 'Payment received',
                '৳ 12,800 from #ORD-8815 (Nagad)', '1h', true),
            (Icons.report, 'Suspicious order flagged',
                '#ORD-8821 looks suspicious', '2h', false),
            (Icons.local_shipping, 'Delivery completed',
                '#ORD-8755 delivered successfully', '5h', false),
            (Icons.local_offer, 'Coupon FESTIVE10 used',
                '12 new uses today', 'Yesterday', false),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: n.$5
                      ? AppColors.primaryContainer.withValues(alpha: 0.4)
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(
                      color: n.$5
                          ? AppColors.primaryFixed
                          : AppColors.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: n.$5
                            ? AppColors.primaryFixed
                            : AppColors.surfaceContainer,
                        borderRadius:
                            BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Icon(
                        n.$1,
                        size: 18,
                        color: n.$5
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
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
                                child: Text(n.$2,
                                    style: AppTypography.bodyMd.copyWith(
                                      fontWeight: FontWeight.w700,
                                    )),
                              ),
                              Text(n.$4,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(n.$3,
                              style: AppTypography.bodySm.copyWith(
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
