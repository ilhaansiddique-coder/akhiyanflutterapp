import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Status pill used in orders / inventory tables.
/// Matches the colored badge style from `dashboard_1/code.html`.
enum StatusKind { delivered, processing, shipped, cancelled, pending, lowStock }

class StatusChip extends StatelessWidget {
  const StatusChip({required this.kind, required this.label, super.key});

  final StatusKind kind;
  final String label;

  ({Color bg, Color fg}) get _palette {
    switch (kind) {
      case StatusKind.delivered:
        return (bg: AppColors.successContainer, fg: AppColors.onSuccessContainer);
      case StatusKind.processing:
      case StatusKind.pending:
        return (bg: AppColors.warningContainer, fg: AppColors.onWarningContainer);
      case StatusKind.shipped:
        return (bg: AppColors.infoContainer, fg: AppColors.onInfoContainer);
      case StatusKind.cancelled:
      case StatusKind.lowStock:
        return (bg: AppColors.errorContainer, fg: AppColors.onErrorContainer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 4,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: p.fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontSize: 10,
        ),
      ),
    );
  }
}
