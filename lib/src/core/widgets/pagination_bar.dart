import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Numbered pagination bar shown at the bottom of list screens.
///
/// Renders a Prev arrow, a compact set of page numbers (always shows first +
/// last + current ± 1, with ellipses bridging any gaps, capped at ~7 visible
/// numbers) and a Next arrow. Hidden entirely when [totalPages] <= 1.
///
/// Example layouts:
///   `<  1  2  3  4  5  >`         (totalPages == 5, current == 3)
///   `<  1  ...  4  [5]  6  ...  12  >`  (totalPages == 12, current == 5)
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.loadingPage,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  /// Page number the user just tapped that is currently being fetched.
  /// When non-null, that button shows a tiny spinner instead of its number,
  /// giving immediate feedback exactly where the tap landed. Cleared by the
  /// caller (typically when `state.loading` flips false).
  final int? loadingPage;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final pages = _buildPageList(currentPage, totalPages);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ArrowButton(
            icon: Icons.chevron_left,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: AppSpacing.xs),
          for (final entry in pages) ...[
            if (entry == null)
              const _Ellipsis()
            else
              _PageButton(
                page: entry,
                active: entry == currentPage,
                loading: entry == loadingPage,
                onTap: () => onPageChanged(entry),
              ),
            const SizedBox(width: AppSpacing.xs),
          ],
          _ArrowButton(
            icon: Icons.chevron_right,
            enabled: currentPage < totalPages,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }

  /// Build the list of page slots to render. `null` = ellipsis.
  ///
  /// Always includes 1, totalPages, current, current-1, current+1. Inserts a
  /// single ellipsis on either side when there's a gap. Caps the visible
  /// numbers at ~7 entries (excluding ellipses).
  static List<int?> _buildPageList(int current, int total) {
    if (total <= 7) {
      return [for (var i = 1; i <= total; i++) i];
    }
    final pages = <int?>[];
    final around = <int>{
      1,
      total,
      current,
      current - 1,
      current + 1,
    }.where((p) => p >= 1 && p <= total).toList()..sort();

    int? last;
    for (final p in around) {
      if (last != null && p - last > 1) {
        pages.add(null); // ellipsis
      }
      pages.add(p);
      last = p;
    }
    return pages;
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? AppColors.onSurface : AppColors.outlineVariant;
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.page,
    required this.active,
    required this.loading,
    required this.onTap,
  });

  final int page;
  final bool active;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.onPrimary : AppColors.onSurface;
    return Material(
      color: active ? AppColors.primary : AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(
          color: active ? AppColors.primary : AppColors.borderSubtle,
        ),
      ),
      child: InkWell(
        onTap: (active || loading) ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  )
                : Text(
                    '$page',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: fg,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Ellipsis extends StatelessWidget {
  const _Ellipsis();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 36,
      child: Center(
        child: Text(
          '…',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
