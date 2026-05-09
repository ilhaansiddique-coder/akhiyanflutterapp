import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/list_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flash sales — list with state badges, active toggle, and delete.
///
/// Mobile does NOT support creating flash sales because the create flow
/// needs a multi-product picker that's a meaningful build on its own.
/// New flash sales are authored on the web admin; mobile is for monitoring
/// and pausing/ending campaigns on the go (the most common admin task).
///
/// Live: the `flash-sales` SSE channel refreshes the list when state
/// changes (countdown to live, transition to ended) or another admin
/// edits.
class FlashSalesScreen extends ConsumerStatefulWidget {
  const FlashSalesScreen({super.key});

  @override
  ConsumerState<FlashSalesScreen> createState() =>
      _FlashSalesScreenState();
}

class _FlashSalesScreenState extends ConsumerState<FlashSalesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncSales = ref.watch(flashSalesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Flash Sales',
          style: context.h3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(flashSalesProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            ListSearchField(
              hint: 'Search by title...',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _CreateOnWebHint(),
            const SizedBox(height: AppSpacing.md),
            asyncSales.when(
              data: (list) => _SalesList(query: _query, items: list),
              loading: () => const ListSkeleton(),
              error: (e, _) => ListInlineError(
                message: describeListError(e, 'Could not load flash sales'),
                onRetry: () => ref.invalidate(flashSalesProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateOnWebHint extends StatelessWidget {
  const _CreateOnWebHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Create new flash sales on the web admin (the product '
              'picker needs more screen real estate). Pause, resume, or '
              'delete campaigns from here.',
              style: context.bodySm
                  .copyWith(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesList extends ConsumerWidget {
  const _SalesList({required this.query, required this.items});
  final String query;
  final List<api.FlashSale> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.trim().toLowerCase();
    final visible = q.isEmpty
        ? items
        : items.where((s) => s.title.toLowerCase().contains(q)).toList();

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(
            q.isEmpty
                ? 'No flash sales yet. Create one on the web admin.'
                : 'No sales match "$query"',
            style: context.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final s in visible) ...[
          _SaleCard(sale: s),
          const SizedBox(height: AppSpacing.sm + 4),
        ],
      ],
    );
  }
}

class _SaleCard extends ConsumerStatefulWidget {
  const _SaleCard({required this.sale});
  final api.FlashSale sale;

  @override
  ConsumerState<_SaleCard> createState() => _SaleCardState();
}

class _SaleCardState extends ConsumerState<_SaleCard> {
  bool _busy = false;

  Future<void> _toggleActive() async {
    setState(() => _busy = true);
    try {
      await ref.read(akhiyanApiProvider).flashSales.update(
        widget.sale.id,
        {'isActive': !widget.sale.isActive},
      );
      if (!mounted) return;
      ref.invalidate(flashSalesProvider);
    } catch (e) {
      if (!mounted) return;
      _toast(describeListError(e, 'Toggle failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this flash sale?'),
        content: Text(
            '"${widget.sale.title}" will end immediately and stop affecting '
            'product prices. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(akhiyanApiProvider)
          .flashSales
          .delete(widget.sale.id);
      if (!mounted) return;
      ref.invalidate(flashSalesProvider);
    } catch (e) {
      if (!mounted) return;
      _toast(describeListError(e, 'Delete failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDateTime(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$m-$day $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        border: Border.all(color: AppColors.slateBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.title.isEmpty ? '(untitled)' : s.title,
                  style: context.h3.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onBackground,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StateBadge(state: s.state),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 4, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.play_arrow, size: 14),
                    const SizedBox(width: 4),
                    Text(_formatDateTime(s.startsAt),
                        style: context.bodySm
                            .copyWith(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.stop, size: 14),
                    const SizedBox(width: 4),
                    Text(_formatDateTime(s.endsAt),
                        style: context.bodySm
                            .copyWith(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 14),
                    const SizedBox(width: 4),
                    Text('${s.productCount} product${s.productCount == 1 ? '' : 's'}',
                        style: context.bodySm
                            .copyWith(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: s.isActive,
                  onChanged: _busy ? null : (_) => _toggleActive(),
                  title: Text(
                    s.isActive ? 'Active' : 'Paused',
                    style: context.bodySm.copyWith(
                      color: s.isActive
                          ? AppColors.onBackground
                          : AppColors.outline,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error),
                onPressed: _busy ? null : _confirmDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (state) {
      'live' => (
          AppColors.successContainer,
          AppColors.onSuccessContainer,
          'LIVE',
        ),
      'scheduled' => (
          AppColors.infoContainer,
          AppColors.onInfoContainer,
          'SCHEDULED',
        ),
      'ended' => (
          AppColors.surfaceContainer,
          AppColors.onSurfaceVariant,
          'ENDED',
        ),
      _ => (
          AppColors.warningContainer,
          AppColors.onWarningContainer,
          'INACTIVE',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: context.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
