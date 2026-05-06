import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class ShortlinksScreen extends StatelessWidget {
  const ShortlinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Shortlinks'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add_link),
        label: const Text('Create Link'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md)
            .copyWith(bottom: AppSpacing.xl + AppSpacing.lg),
        children: [
          for (final l in const [
            ('akh.iy/winter', 'Winter Sale Landing', 1240, 89),
            ('akh.iy/runner-fb', 'Runners FB Campaign', 845, 42),
            ('akh.iy/headset-ig', 'Headset IG Story', 312, 18),
            ('akh.iy/vip-launch', 'VIP Pre-launch', 156, 67),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(AppRadius.medium),
                          ),
                          child: const Icon(Icons.link,
                              color: AppColors.primaryFixed, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.$1,
                                  style: AppTypography.dataDisplay.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  )),
                              Text(l.$2,
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  )),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        _Metric('${l.$3} clicks', Icons.touch_app_outlined),
                        const SizedBox(width: AppSpacing.lg),
                        _Metric('${l.$4} conversions',
                            Icons.shopping_cart_outlined),
                      ],
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

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label,
            style: AppTypography.caption.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}
