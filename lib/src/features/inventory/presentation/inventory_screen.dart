import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/coming_soon.dart';
import 'package:akhiyan_admin/src/core/widgets/notification_bell.dart';
import 'package:akhiyan_admin/src/core/widgets/page_loading_overlay.dart';
import 'package:akhiyan_admin/src/core/widgets/pagination_bar.dart';
import 'package:akhiyan_admin/src/core/widgets/skeleton.dart';

/// Inventory list — derived from the products endpoint via
/// [inventoryListProvider]. Numbered pagination matches the products /
/// orders / customers screens.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  /// Page number the user just tapped that is currently being fetched.
  /// Drives the inline pagination-button spinner and the overlay label.
  int? _loadingPage;

  void _goToPage(int p) {
    setState(() => _loadingPage = p);
    ref.read(inventoryListProvider.notifier).goToPage(p);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryListProvider);
    if (!state.loading && _loadingPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(inventoryListProvider).loading) {
          setState(() => _loadingPage = null);
        }
      });
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ),
        title: const Text('Inventory'),
        actions: [
          const NotificationBell(),
          IconButton(
            onPressed: () =>
                ref.read(inventoryListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: Builder(
        builder: (_) {
          // First-page loading: skeleton placeholders so the layout doesn't
          // jump when items arrive.
          if (state.loading && state.items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                for (int i = 0; i < 8; i++) ...const [
                  _InventoryRowSkeleton(),
                  SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          }
          // Error on first load: keep the existing 404 -> coming-soon branch
          // for safety even though /products shouldn't 404.
          if (state.error != null && state.items.isEmpty) {
            final e = state.error!;
            if (e is api.ApiException && e.isNotFound) {
              return comingSoonBody('Inventory');
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(_describeError(e), textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(inventoryListProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = state.items;
          // TODO: per-page totals; replace with /inventory/summary when backend exposes it.
          final lowStock = items.where((p) => p.level == 'low').length;
          final outOfStock = items.where((p) => p.level == 'critical').length;
          final healthy = items
              .where((p) => p.level == 'ok' || p.level == 'unlimited')
              .length;

          final isPageSwitching =
                    _loadingPage != null && state.loading && state.items.isNotEmpty;
          final list = RefreshIndicator(
            onRefresh: () =>
                ref.read(inventoryListProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _InventoryStat(
                            'Healthy', '$healthy', AppColors.success)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: _InventoryStat(
                            'Low Stock', '$lowStock', AppColors.warning)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: _InventoryStat('Out of Stock', '$outOfStock',
                            AppColors.error)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Stock Levels',
                    style: context.h3.copyWith(fontSize: 18)),
                const SizedBox(height: AppSpacing.sm),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: Text(
                        'No inventory data yet',
                        style: context.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _InventoryRow(item: items[i]),
                        ],
                      ],
                    ),
                  ),
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
                  targetPage: _loadingPage ?? state.currentPage,
                ),
            ],
          );
        },
      ),
    );
  }
}

String _describeError(Object e) {
  if (e is api.ApiException) return e.message;
  if (e is api.NetworkException) return 'No internet connection';
  return 'Could not load inventory';
}

class _InventoryStat extends StatelessWidget {
  const _InventoryStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              style: AppTypography.dataDisplayLg.copyWith(
                fontSize: 22,
                color: color,
              )),
          Text(label,
              style: context.caption.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.item});
  final api.InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.level) {
      'critical' => AppColors.error,
      'low' => AppColors.warning,
      _ => AppColors.success,
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: SizedBox(
              width: 48,
              height: 48,
              child: item.image.isEmpty
                  ? const ColoredBox(
                      color: AppColors.surfaceContainer,
                      child: Icon(Icons.image_outlined,
                          color: AppColors.onSurfaceVariant),
                    )
                  : Image.network(
                      item.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.surfaceContainer,
                        child: Icon(Icons.image_outlined,
                            color: AppColors.onSurfaceVariant),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: context.bodyMd
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(item.slug,
                    style: context.caption
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.unlimitedStock ?? false ? '∞' : '${item.stock}',
                style: AppTypography.dataDisplay.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Text('units',
                  style: context.caption
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: () => context.push('/products/${item.id}'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ─── Inventory row skeleton (first-load placeholder) ────────────────────

class _InventoryRowSkeleton extends StatelessWidget {
  const _InventoryRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            SkeletonBox(width: 56, height: 56, radius: AppRadius.medium),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 180),
                  SizedBox(height: 6),
                  SkeletonText(width: 100, fontSize: 13),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.md),
            SkeletonText(width: 50),
          ],
        ),
      ),
    );
  }
}
