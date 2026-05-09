import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:flutter/material.dart';

/// One of the 4 KPI cards on the dashboard (Today's Orders, Revenue, Pending,
/// Low Stock). Matches `dashboard_1/code.html` — left accent stripe is
/// optional and used for warning/error variants.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.trendLabel,
    this.iconBg = AppColors.secondaryContainer,
    this.iconColor = AppColors.onSecondaryContainer,
    this.valueColor,
    this.accentColor,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? trendLabel;
  final Color iconBg;
  final Color iconColor;
  final Color? valueColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      foregroundDecoration: accentColor == null
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border(
                left: BorderSide(color: accentColor!, width: 4),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              if (trendLabel != null)
                Text(
                  trendLabel!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: accentColor ?? AppColors.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.dataDisplayLg.copyWith(
              color: valueColor ?? AppColors.primary,
              fontSize: 32,
            ),
          ),
        ],
      ),
    );
  }
}
