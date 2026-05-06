import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_drawer.dart';

class FlashSalesScreen extends StatelessWidget {
  const FlashSalesScreen({super.key});

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
        title: const Text('Flash Sales'),
        actions: [
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
        icon: const Icon(Icons.bolt),
        label: const Text('New Flash Sale'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md)
            .copyWith(bottom: AppSpacing.xl + AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: AppColors.onPrimary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('LIVE NOW',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        )),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Winter Mega Sale',
                    style: AppTypography.h2.copyWith(
                      color: AppColors.onPrimary,
                      fontSize: 22,
                    )),
                const SizedBox(height: AppSpacing.xs),
                Text('Up to 50% off — ends in 4h 23m',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.primaryFixed,
                    )),
                const SizedBox(height: AppSpacing.md),
                const Row(
                  children: [
                    _LiveStat(value: '142', label: 'Orders'),
                    SizedBox(width: AppSpacing.lg),
                    _LiveStat(value: '৳ 84K', label: 'Revenue'),
                    SizedBox(width: AppSpacing.lg),
                    _LiveStat(value: '23%', label: 'Conversion'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Upcoming',
              style: AppTypography.h3.copyWith(fontSize: 18)),
          const SizedBox(height: AppSpacing.sm),
          for (final s in const [
            ('Eid Special', 'Apr 15 — Apr 18', '30% OFF'),
            ('Independence Day', 'Mar 26', '26% OFF'),
            ('New Year Blowout', 'Dec 31 — Jan 5', '40% OFF'),
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
                    const Icon(Icons.event, color: AppColors.primary),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warningContainer,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(s.$3,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onWarningContainer,
                            fontWeight: FontWeight.w800,
                          )),
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

class _LiveStat extends StatelessWidget {
  const _LiveStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: AppTypography.dataDisplayLg.copyWith(
              color: AppColors.onPrimary,
              fontSize: 22,
            )),
        Text(label,
            style: AppTypography.caption.copyWith(
              color: AppColors.primaryFixed,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}
