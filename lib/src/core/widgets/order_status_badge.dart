import 'package:flutter/material.dart';

import 'package:akhiyan_admin/src/features/orders/domain/order.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';

/// Pill-style status badge used in orders list / detail. Matches the
/// container palette in `orders_list_1` prototype: light-tinted backgrounds
/// with a darker `on-` foreground.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({required this.status, super.key});

  final OrderStatus status;

  ({Color bg, Color fg, String label}) get _meta {
    switch (status) {
      case OrderStatus.pending:
        return (
          bg: AppColors.errorContainer,
          fg: AppColors.onErrorContainer,
          label: 'Pending'
        );
      case OrderStatus.confirmed:
        return (
          bg: AppColors.surfaceContainerHigh,
          fg: AppColors.onSurfaceVariant,
          label: 'Confirmed'
        );
      case OrderStatus.processing:
        return (
          bg: AppColors.secondaryFixed,
          fg: AppColors.onSecondaryFixed,
          label: 'Processing'
        );
      case OrderStatus.shipped:
        return (
          bg: AppColors.infoContainer,
          fg: AppColors.onInfoContainer,
          label: 'Shipped'
        );
      case OrderStatus.delivered:
        return (
          bg: AppColors.successContainer,
          fg: AppColors.onSuccessContainer,
          label: 'Delivered'
        );
      case OrderStatus.cancelled:
        return (
          bg: AppColors.errorContainer,
          fg: AppColors.onErrorContainer,
          label: 'Cancelled'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 4,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: m.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        m.label,
        style: AppTypography.caption.copyWith(
          color: m.fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
