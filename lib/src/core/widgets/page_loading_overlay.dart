import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:flutter/material.dart';

/// Centered "Loading page X..." card shown on top of a dimmed list while a
/// pagination fetch is in flight. The list itself should be wrapped with an
/// `IgnorePointer` + `Opacity(0.6)` so it visually ghosts while still
/// occupying its layout space (no jank when the new page arrives).
///
/// Used by the products / inventory / orders / customers screens; do NOT
/// show this on the first-load case — those screens render skeleton rows
/// instead.
class PageLoadingOverlay extends StatelessWidget {
  const PageLoadingOverlay({required this.targetPage, super.key});

  /// 1-based page number the user just tapped. Shown in the label so the
  /// feedback ties directly to the page button they pressed.
  final int targetPage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: AppColors.surfaceContainerLowest,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.md - 4),
              Text(
                'Loading page $targetPage...',
                style: context.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
