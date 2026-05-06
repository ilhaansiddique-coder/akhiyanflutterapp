import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class CourierScreen extends StatelessWidget {
  const CourierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Courier Management'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Connected Couriers',
              style: AppTypography.h3.copyWith(fontSize: 18)),
          const SizedBox(height: AppSpacing.sm),
          for (final c in const [
            ('Pathao', true, 142, '94%'),
            ('Sundarban', true, 87, '91%'),
            ('Steadfast', false, 0, '—'),
            ('Paperfly', true, 24, '88%'),
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.$2
                            ? AppColors.primaryContainer
                            : AppColors.surfaceContainer,
                        borderRadius:
                            BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Icon(
                        Icons.local_shipping,
                        color: c.$2
                            ? AppColors.primaryFixed
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
                              Text(c.$1,
                                  style: AppTypography.bodyMd
                                      .copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.$2
                                      ? AppColors.successContainer
                                      : AppColors.surfaceContainer,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.small),
                                ),
                                child: Text(
                                  c.$2 ? 'CONNECTED' : 'DISCONNECTED',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: c.$2
                                        ? AppColors.onSuccessContainer
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                              '${c.$3} active shipments • ${c.$4} on-time rate',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              )),
                        ],
                      ),
                    ),
                    Switch(value: c.$2, onChanged: (_) {}),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
