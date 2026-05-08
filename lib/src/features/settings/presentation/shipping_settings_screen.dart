import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shipping Zones — placeholder.
///
/// Zones live in their own Prisma table (separate from the key/value
/// `siteSetting` rows the other settings screens edit) and have a
/// list+CRUD shape: name, country, regions list, weight tiers, base rate,
/// per-kg rate. Building a phone editor is non-trivial — needs nested
/// list editing for regions and tiers — so it stays on web for now.
///
/// When we're ready: add `/api/v1/m/shipping-zones` re-export, a
/// `ShippingZonesApi`, and replace this placeholder with a list+form pair
/// shaped like LandingPagesScreen + LandingPageFormScreen.
class ShippingSettingsScreen extends ConsumerWidget {
  const ShippingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Shipping Zones',
          style: AppTypography.h3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.warningContainer,
              borderRadius: BorderRadius.circular(AppRadius.xLarge),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping_outlined, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Manage shipping zones on web',
                  style: AppTypography.h3.copyWith(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Zones, regions, weight tiers, and per-kg rates need a '
                  'multi-level editor that fits the web admin better. '
                  'Settings → Shipping on web admin.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm
                      .copyWith(fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
