import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/akhiyan_api.dart' as api;
import '../../../core/api/api_providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/coming_soon.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInv = ref.watch(inventoryListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Inventory'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(inventoryListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: asyncInv.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => (e is api.ApiException && e.isNotFound)
            ? comingSoonBody('Inventory')
            : Center(
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
                  onPressed: () => ref.invalidate(inventoryListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (result) {
          final items = result.data;
          final lowStock =
              items.where((p) => p.level == 'low').length;
          final outOfStock =
              items.where((p) => p.level == 'critical').length;
          final healthy = items
              .where((p) => p.level == 'ok' || p.level == 'unlimited')
              .length;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(inventoryListProvider);
              await ref.read(inventoryListProvider.future);
            },
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
                    style: AppTypography.h3.copyWith(fontSize: 18)),
                const SizedBox(height: AppSpacing.sm),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: Text(
                        'No inventory data yet',
                        style: AppTypography.bodyMd.copyWith(
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
              ],
            ),
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
              style: AppTypography.caption.copyWith(
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
                  ? Container(
                      color: AppColors.surfaceContainer,
                      child: const Icon(Icons.image_outlined,
                          color: AppColors.onSurfaceVariant),
                    )
                  : Image.network(
                      item.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.surfaceContainer,
                        child: const Icon(Icons.image_outlined,
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
                    style: AppTypography.bodyMd
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(item.slug,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.unlimitedStock == true ? '∞' : '${item.stock}',
                style: AppTypography.dataDisplay.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Text('units',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
