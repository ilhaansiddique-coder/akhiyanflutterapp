import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({required this.customerId, super.key});
  final String customerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Customer $customerId'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryFixed,
                  child: Text(
                    'R',
                    style: AppTypography.h1.copyWith(
                      color: AppColors.primary,
                      fontSize: 36,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Rahat Chowdhury',
                    style: AppTypography.h2.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontSize: 20,
                    )),
                const SizedBox(height: 4),
                Text('+880 1711-223344',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onPrimaryContainer,
                    )),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.message_outlined, size: 18),
                        label: const Text('Message'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.onPrimaryContainer,
                          side: const BorderSide(
                              color: AppColors.onPrimaryContainer),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _StatsRow(),
          const SizedBox(height: AppSpacing.md),
          _AddressCard(),
          const SizedBox(height: AppSpacing.md),
          _RecentOrders(),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _Stat(value: '12', label: 'Orders')),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _Stat(value: '৳48,500', label: 'Total Spent')),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _Stat(value: '3.8★', label: 'Rating')),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(value,
              style: AppTypography.dataDisplayLg.copyWith(fontSize: 22)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.caption.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Address', style: AppTypography.h3.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'House 24, Road 7, Block D, Banani, Dhaka-1213, Bangladesh',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Orders',
                    style: AppTypography.h3.copyWith(fontSize: 16)),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
          ),
          for (final entry in const [
            ('#ORD-8821', '৳ 4,250', 'Pending'),
            ('#ORD-8755', '৳ 12,800', 'Delivered'),
            ('#ORD-8624', '৳ 3,490', 'Delivered'),
          ]) ...[
            const Divider(height: 1),
            ListTile(
              title: Text(entry.$1, style: AppTypography.bodyMd),
              subtitle: Text(entry.$2,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  )),
              trailing: Text(entry.$3,
                  style: AppTypography.caption.copyWith(
                    color: entry.$3 == 'Pending'
                        ? AppColors.error
                        : AppColors.success,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ],
      ),
    );
  }
}
