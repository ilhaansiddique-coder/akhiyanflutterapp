import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_card.dart';
import 'package:akhiyan_admin/src/core/widgets/app_shell_app_bar.dart';
import 'package:akhiyan_admin/src/core/widgets/page_loading_overlay.dart';
import 'package:akhiyan_admin/src/core/widgets/pagination_bar.dart';
import 'package:akhiyan_admin/src/core/widgets/skeleton.dart';
import 'package:akhiyan_admin/src/features/products/domain/product.dart';

enum _ProductFilter { all, active, draft, lowStock, outOfStock }

/// Products list — wired to the live `/products` endpoint via
/// [productsListProvider].
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  _ProductFilter _filter = _ProductFilter.all;
  String _query = '';

  /// Page number the user just tapped that is currently being fetched.
  /// Drives the inline spinner inside the [PaginationBar] and the centered
  /// "Loading page X..." overlay. Cleared once `state.loading` flips false.
  int? _loadingPage;

  void _goToPage(int p) {
    setState(() => _loadingPage = p);
    ref.read(productsListProvider.notifier).goToPage(p);
  }

  bool _matchesFilter(api.Product p) {
    final state = stockStateOf(p);
    switch (_filter) {
      case _ProductFilter.active:
        return p.isActive;
      case _ProductFilter.draft:
        return !p.isActive;
      case _ProductFilter.lowStock:
        return state == StockState.low;
      case _ProductFilter.outOfStock:
        return state == StockState.out;
      case _ProductFilter.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsListProvider);
    // Clear the tap-tracked target once the fetch resolves so the bar's
    // inline spinner stops.
    if (!state.loading && _loadingPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(productsListProvider).loading) {
          setState(() => _loadingPage = null);
        }
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: const AppShellAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.outline,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        borderSide: const BorderSide(
                          color: AppColors.borderSubtle,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        borderSide: const BorderSide(
                          color: AppColors.borderSubtle,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: () => context.push('/products/new'),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    textStyle: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                for (final f in _ProductFilter.values)
                  _FilterChip(
                    label: _label(f),
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Builder(
              builder: (_) {
                if (state.loading && state.items.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    children: [
                      for (int i = 0; i < 8; i++) ...const [
                        _ProductCardSkeleton(),
                        SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                }
                if (state.error != null && state.items.isEmpty) {
                  return _ErrorView(
                    message: _describeError(state.error!),
                    onRetry: () =>
                        ref.read(productsListProvider.notifier).refresh(),
                  );
                }
                final visible = state.items.where((p) {
                  if (!_matchesFilter(p)) return false;
                  if (_query.isEmpty) return true;
                  return p.name
                      .toLowerCase()
                      .contains(_query.toLowerCase());
                }).toList();
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      state.items.isEmpty
                          ? 'No products yet'
                          : 'No products match your filters',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final isPageSwitching =
                    _loadingPage != null && state.loading && state.items.isNotEmpty;
                final list = RefreshIndicator(
                  onRefresh: () =>
                      ref.read(productsListProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    children: [
                      for (var i = 0; i < visible.length; i++) ...[
                        _ProductCard(
                          product: visible[i],
                          onTap: () =>
                              context.push('/products/${visible[i].id}'),
                        ),
                        if (i != visible.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                      PaginationBar(
                        currentPage: state.currentPage,
                        totalPages: state.totalPages,
                        loadingPage: isPageSwitching ? _loadingPage : null,
                        onPageChanged: _goToPage,
                      ),
                    ],
                  ),
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      ignoring: isPageSwitching,
                      child: AnimatedOpacity(
                        opacity: isPageSwitching ? 0.6 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: list,
                      ),
                    ),
                    if (isPageSwitching)
                      PageLoadingOverlay(
                        targetPage:
                            _loadingPage ?? state.currentPage,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _label(_ProductFilter f) => switch (f) {
        _ProductFilter.all => 'All',
        _ProductFilter.active => 'Active',
        _ProductFilter.draft => 'Draft',
        _ProductFilter.lowStock => 'Low Stock',
        _ProductFilter.outOfStock => 'Out of Stock',
      };
}

String _describeError(Object e) {
  if (e is api.ApiException) return e.message;
  if (e is api.NetworkException) return 'No internet connection';
  return 'Could not load products';
}

/// Derives a [StockState] from an api [api.Product].
StockState stockStateOf(api.Product p) {
  if (p.unlimitedStock ?? false) return StockState.healthy;
  if (p.stock <= 0) return StockState.out;
  if (p.stock <= 5) return StockState.low;
  return StockState.healthy;
}

// ─── Filter chip ─────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: selected
            ? AppColors.primary
            : AppColors.surfaceContainerLowest,
        elevation: selected ? 1 : 0,
        shadowColor: AppColors.primary.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.borderSubtle,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Error view ─────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ─── Product card skeleton (first-load placeholder) ──────────────────────

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          SkeletonBox(width: 64, height: 64, radius: AppRadius.medium),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 180),
                SizedBox(height: 8),
                SkeletonText(fontSize: 13),
                SizedBox(height: 8),
                SkeletonBox(width: 60, height: 16, radius: AppRadius.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Product card ────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});
  final api.Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = stockStateOf(product);
    final stockColor = switch (state) {
      StockState.healthy => AppColors.onSurfaceVariant,
      StockState.low => AppColors.error,
      StockState.out => AppColors.error,
    };
    final stockLabel = product.unlimitedStock ?? false
        ? 'In stock'
        : state == StockState.out
            ? 'Out of Stock'
            : '${product.stock} in stock';
    final (badgeBg, badgeFg, badgeBorder, badgeLabel) = product.isActive
        ? (
            AppColors.successContainer,
            AppColors.onSuccessContainer,
            AppColors.success.withValues(alpha: 0.2),
            'ACTIVE',
          )
        : (
            AppColors.surfaceContainer,
            AppColors.onSurfaceVariant,
            AppColors.outlineVariant,
            'DRAFT',
          );

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: SizedBox(
              width: 64,
              height: 64,
              child: product.image.isEmpty
                  ? const ColoredBox(
                      color: AppColors.surfaceContainer,
                      child: Icon(
                        Icons.image_outlined,
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  : Image.network(
                      product.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.surfaceContainer,
                        child: Icon(
                          Icons.image_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: AppTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '৳ ${product.price.toStringAsFixed(0)}',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      stockLabel,
                      style: AppTypography.bodySm.copyWith(
                        color: stockColor,
                        fontWeight: state == StockState.healthy
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Text(
                    badgeLabel,
                    style: AppTypography.caption.copyWith(
                      color: badgeFg,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
