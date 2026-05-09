import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:flutter/material.dart';

/// Shared building blocks for the simpler "list of cards" admin screens
/// (Categories, Brands, Incomplete Orders). Extracted because each screen
/// reuses the same search field + thumbnail + count pill + skeleton + error
/// shape — duplicating ~150 lines across three files added no clarity.
///
/// The richer list screens (Products, Orders, Customers) keep their own
/// private versions because their cards carry feature-specific bits
/// (variants, status badges, role pills) that don't generalise.

class ListSearchField extends StatelessWidget {
  const ListSearchField({required this.hint, required this.onChanged, super.key});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon:
            const Icon(Icons.search, size: 20, color: AppColors.outline),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }
}

class ListThumbnail extends StatelessWidget {
  const ListThumbnail({
    required this.imageUrl, required this.fallbackInitial, super.key,
  });

  final String? imageUrl;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    final initial = fallbackInitial.trim().isEmpty
        ? '?'
        : fallbackInitial.trim()[0].toUpperCase();
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _initialText(initial),
            )
          : _initialText(initial),
    );
  }

  Widget _initialText(String initial) => Text(
        initial,
        style: AppTypography.h3.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      );
}

class ListCountPill extends StatelessWidget {
  const ListCountPill({required this.count, required this.active, super.key});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg =
        active ? AppColors.primaryContainer : AppColors.surfaceContainer;
    final fg =
        active ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.slateBorder),
      ),
      child: Text(
        '$count',
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.xLarge),
              border: Border.all(color: AppColors.slateBorder),
            ),
          ),
        ),
      ),
    );
  }
}

class ListInlineError extends StatelessWidget {
  const ListInlineError(
      {required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String describeListError(Object e, String fallback) {
  if (e is api.ApiException) return e.message;
  if (e is api.NetworkException) return 'No internet connection';
  return fallback;
}
