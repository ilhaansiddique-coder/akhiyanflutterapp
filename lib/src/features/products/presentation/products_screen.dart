import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_shell_app_bar.dart';
import 'package:akhiyan_admin/src/core/widgets/page_loading_overlay.dart';
import 'package:akhiyan_admin/src/core/widgets/pagination_bar.dart';
import 'package:akhiyan_admin/src/core/widgets/skeleton.dart';
import 'package:akhiyan_admin/src/features/products/domain/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Products list — wired to the live `/products` endpoint via
/// [productsListProvider]. Cards mirror the design spec: image + title +
/// Bangla subtitle + price, status badge + stock + sold, variant chip
/// grid, and four colored action icons (view / edit / duplicate /
/// delete). Bulk selection sits up top with a trash button that's
/// disabled until at least one row is checked. Pagination stays at the
/// bottom of the list.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';

  /// Page number the user just tapped that is currently being fetched.
  /// Drives the inline spinner inside the [PaginationBar] and the centered
  /// "Loading page X..." overlay. Cleared once `state.loading` flips false.
  int? _loadingPage;

  /// IDs of products currently checked. Survives across re-renders but
  /// resets when the user changes pages (selecting on page 1 then jumping
  /// to page 2 would otherwise create a confusing "select all" state
  /// across pages).
  final Set<String> _selectedIds = <String>{};

  bool _bulkDeleting = false;

  void _goToPage(int p) {
    setState(() {
      _loadingPage = p;
      _selectedIds.clear(); // selection is page-scoped
    });
    ref.read(productsListProvider.notifier).goToPage(p);
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<api.Product> visible) {
    setState(() {
      if (_selectedIds.length == visible.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(visible.map((p) => p.id));
      }
    });
  }

  Future<void> _confirmAndBulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final n = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete products?'),
        content: Text(
          'This will move $n product${n == 1 ? '' : 's'} to trash. You can '
          'restore them from the admin web UI within 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete $n'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _bulkDeleting = true);
    final productsApi = ref.read(akhiyanApiProvider).products;
    final ids = List<String>.from(_selectedIds);
    var failed = 0;
    // Run deletes in parallel — backend is soft-delete + idempotent so this
    // is safe even if the user double-taps.
    await Future.wait(ids.map((id) async {
      try {
        await productsApi.delete(id);
      } on Exception {
        failed++;
      }
    }));
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _bulkDeleting = false;
    });
    // Re-fetch the current page so the rows actually disappear.
    await ref.read(productsListProvider.notifier).refresh();
    if (!mounted) return;
    final ok2 = ids.length - failed;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: failed == 0 ? AppColors.success : AppColors.error,
        content: Text(
          failed == 0
              ? 'Deleted $ok2 product${ok2 == 1 ? '' : 's'}'
              : 'Deleted $ok2, failed $failed',
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteSingle(api.Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('"${p.name}" will be moved to trash.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(akhiyanApiProvider).products.delete(p.id);
      await ref.read(productsListProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Deleted "${p.name}"'),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Delete failed: $e'),
        ),
      );
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
          // Search + bulk-delete + add row
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
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: const BorderSide(
                          color: AppColors.borderSubtle,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: const BorderSide(
                          color: AppColors.borderSubtle,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _IconCircleButton(
                  icon: Icons.delete_outline,
                  // Disabled until at least one product is checked.
                  enabled: _selectedIds.isNotEmpty && !_bulkDeleting,
                  onTap: _confirmAndBulkDelete,
                  tooltip: _selectedIds.isEmpty
                      ? 'Select products to delete'
                      : 'Delete ${_selectedIds.length} selected',
                  loading: _bulkDeleting,
                ),
                const SizedBox(width: AppSpacing.sm),
                _IconCircleButton(
                  icon: Icons.add,
                  enabled: true,
                  filled: true,
                  onTap: () => context.push('/products/new'),
                  tooltip: 'Add product',
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: Builder(
              builder: (_) {
                if (state.loading && state.items.isEmpty) {
                  return ListView(
                    // Bottom padding clears the floating BottomAppBar
                    // (height 76 in app_shell.dart) plus ~24 of breathing
                    // room. Without this, `extendBody: true` lets content
                    // — including the PaginationBar — slide behind the bar.
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      100,
                    ),
                    children: [
                      for (int i = 0; i < 6; i++) ...const [
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
                      style: context.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final allChecked = _selectedIds.length == visible.length;
                final someChecked = _selectedIds.isNotEmpty && !allChecked;
                final isPageSwitching =
                    _loadingPage != null && state.loading && state.items.isNotEmpty;
                final list = RefreshIndicator(
                  onRefresh: () =>
                      ref.read(productsListProvider.notifier).refresh(),
                  child: ListView(
                    // Bottom padding clears the floating BottomAppBar
                    // (height 76 in app_shell.dart) plus ~24 of breathing
                    // room. Without this, `extendBody: true` lets content
                    // — including the PaginationBar — slide behind the bar.
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      100,
                    ),
                    children: [
                      _SelectAllBar(
                        total: state.total > 0
                            ? state.total
                            : visible.length,
                        checked: allChecked,
                        partial: someChecked,
                        onTap: () => _toggleSelectAll(visible),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (var i = 0; i < visible.length; i++) ...[
                        _ProductCard(
                          product: visible[i],
                          selected: _selectedIds.contains(visible[i].id),
                          onSelectionToggle: () =>
                              _toggleSelect(visible[i].id),
                          onView: () =>
                              context.push('/products/${visible[i].id}'),
                          onEdit: () =>
                              context.push('/products/${visible[i].id}'),
                          onDuplicate: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Duplicate is not implemented yet',
                                ),
                              ),
                            );
                          },
                          onDelete: () =>
                              _confirmAndDeleteSingle(visible[i]),
                        ),
                        if (i != visible.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                      const SizedBox(height: AppSpacing.md),
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

// ─── Top "Select all (N)" bar ────────────────────────────────────────────

class _SelectAllBar extends StatelessWidget {
  const _SelectAllBar({
    required this.total,
    required this.checked,
    required this.partial,
    required this.onTap,
  });
  final int total;
  final bool checked;
  final bool partial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: partial ? null : checked,
                  tristate: true,
                  onChanged: (_) => onTap(),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text(
                'Select all ($total)',
                style: context.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Round icon button (delete + add) ────────────────────────────────────

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
    this.filled = false,
    this.loading = false,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? AppColors.primary
        : (enabled
            ? AppColors.surfaceContainerLowest
            : AppColors.surfaceContainer);
    final fg = filled
        ? AppColors.onPrimary
        : (enabled ? AppColors.error : AppColors.outline);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        elevation: filled ? 4 : 0,
        shadowColor: filled ? AppColors.primary.withValues(alpha: 0.3) : null,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Icon(icon, size: 22, color: fg),
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
              style: context.bodyMd,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: const Row(
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

/// Card layout (matches design spec):
/// ```text
/// ┌──────────────────────────────────────────────────┐
/// │ [☐]  ┌────┐  Title — bold              ৳PRICE   │
/// │      │IMG │  bn-subtitle                        │
/// │      └────┘                                     │
/// │       [Active]   N stock      M sold            │
/// │                                                 │
/// │       [chip] [chip] [chip] [chip]               │
/// │       [chip] [chip]                             │
/// │                                                 │
/// │                       [👁] [✏] [📋] [🗑]        │
/// └──────────────────────────────────────────────────┘
/// ```
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.selected,
    required this.onSelectionToggle,
    required this.onView,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });
  final api.Product product;
  final bool selected;
  final VoidCallback onSelectionToggle;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final stockText = (product.unlimitedStock ?? false)
        ? '∞ Stock'
        : '${product.stock} stock';
    final soldText = '${product.soldCount} sold';
    final categoryBn = (product.category != null
            ? (product.category!['nameBn'] ?? product.category!['name_bn'])
            : null)
        ?.toString();
    final categoryName = (product.category != null
            ? (product.category!['name'])
            : null)
        ?.toString();
    final subtitle = categoryBn ?? categoryName ?? '';
    final hasBadge = product.badge != null && product.badge!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: selected
              ? AppColors.primary
              : AppColors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Top row: checkbox + image + title/subtitle + price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => onSelectionToggle(),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: SizedBox(
                  width: 56,
                  height: 56,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            // Bricolage face for the product title (heading
                            // identity matches the rest of the app).
                            style: context.h3.copyWith(
                              fontSize: 16,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '৳${product.price.toStringAsFixed(0)}',
                          style: context.bodyMd.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty || hasBadge) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (subtitle.isNotEmpty)
                            Flexible(
                              child: Text(
                                subtitle,
                                style: context.bodySm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (subtitle.isNotEmpty && hasBadge)
                            Text(
                              ' • ',
                              style: context.bodySm.copyWith(
                                color: AppColors.outlineVariant,
                              ),
                            ),
                          if (hasBadge)
                            Text(
                              product.badge!,
                              style: context.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // ─── Status badge + stock + sold (lives indented under the image)
          Padding(
            padding: const EdgeInsets.only(left: 22 + AppSpacing.sm),
            child: Row(
              children: [
                _StatusPill(active: product.isActive),
                const SizedBox(width: AppSpacing.s12),
                Text(
                  stockText,
                  style: context.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  soldText,
                  style: context.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // ─── Variant chips grid
          if (product.variants != null && product.variants!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 22 + AppSpacing.sm),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in product.variants!)
                    _VariantChip(
                      label: v.label,
                      stock: (v.unlimitedStock ?? false)
                          ? '∞'
                          : v.stock.toString(),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // ─── Action icons (right-aligned)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionIcon(
                icon: Icons.visibility_outlined,
                color: const Color(0xFF10B981),
                tooltip: 'View',
                onTap: onView,
              ),
              const SizedBox(width: 4),
              _ActionIcon(
                icon: Icons.edit_outlined,
                color: const Color(0xFF3B82F6),
                tooltip: 'Edit',
                onTap: onEdit,
              ),
              const SizedBox(width: 4),
              _ActionIcon(
                icon: Icons.copy_all_outlined,
                color: const Color(0xFF8B5CF6),
                tooltip: 'Duplicate',
                onTap: onDuplicate,
              ),
              const SizedBox(width: 4),
              _ActionIcon(
                icon: Icons.delete_outline,
                color: AppColors.error,
                tooltip: 'Delete',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Status pill ────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppColors.successContainer
        : AppColors.surfaceContainer;
    final fg = active
        ? AppColors.onSuccessContainer
        : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        active ? 'Active' : 'Draft',
        style: context.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── Variant chip ───────────────────────────────────────────────────────

class _VariantChip extends StatelessWidget {
  const _VariantChip({required this.label, required this.stock});
  final String label;
  final String stock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        '$label : $stock',
        style: context.caption.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ─── Action icon ─────────────────────────────────────────────────────────

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Icon(icon, size: 20, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
