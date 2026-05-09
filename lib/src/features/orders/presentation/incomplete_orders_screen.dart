import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/sync/sync_client.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/list_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Orders the admin still has to act on — pending/processing/on_hold/confirmed
/// (everything that isn't shipped, delivered, cancelled, returned, or trashed).
///
/// Mirrors the web admin's `/dashboard/orders/incomplete` view in spirit but
/// re-uses the regular `/m/orders` endpoint with a status filter so we don't
/// add another mobile route. The web `incomplete-orders` endpoint is for
/// abandoned-checkout sessions — a different concept that doesn't have a
/// mobile counterpart yet.
///
/// Live-refreshes via the SSE `orders` channel through the central
/// `syncInvalidationProvider` (any new pending order pushed by the storefront
/// shows up here within a few seconds without a refresh).
final incompleteOrdersProvider =
    FutureProvider.autoDispose<List<api.OrderListItem>>((ref) async {
  // Re-evaluate on `orders` bumps so a new checkout shows up live. We're
  // already inside the autoDispose scope so the watch goes away when the
  // user leaves the screen.
  ref.watch(syncVersionProvider('orders'));
  final orders = ref.watch(akhiyanApiProvider).orders;

  // The list endpoint takes a single status string. Fan out across the
  // in-flight statuses and merge — server response sizes are small (one
  // page each, default 20) so this stays cheap even on slow networks.
  const inFlight = ['pending', 'processing', 'on_hold', 'confirmed'];
  final pages = await Future.wait(
    inFlight.map((s) => orders.list(status: s, pageSize: 50)),
  );
  final all = <api.OrderListItem>[];
  final seen = <String>{};
  for (final p in pages) {
    for (final o in p.data) {
      if (seen.add(o.id)) all.add(o);
    }
  }
  // Newest first.
  all.sort((a, b) {
    final ad = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final bd = b.createdAt?.millisecondsSinceEpoch ?? 0;
    return bd.compareTo(ad);
  });
  return all;
});

class IncompleteOrdersScreen extends ConsumerStatefulWidget {
  const IncompleteOrdersScreen({super.key});

  @override
  ConsumerState<IncompleteOrdersScreen> createState() =>
      _IncompleteOrdersScreenState();
}

class _IncompleteOrdersScreenState
    extends ConsumerState<IncompleteOrdersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncOrders = ref.watch(incompleteOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Incomplete Orders',
          style: AppTypography.h3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(incompleteOrdersProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            ListSearchField(
              hint: 'Search by id, name, or phone...',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.md),
            asyncOrders.when(
              data: (list) =>
                  _IncompleteOrdersList(query: _query, items: list),
              loading: () => const ListSkeleton(),
              error: (e, _) => ListInlineError(
                message: describeListError(e, 'Could not load orders'),
                onRetry: () => ref.invalidate(incompleteOrdersProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncompleteOrdersList extends StatelessWidget {
  const _IncompleteOrdersList({required this.query, required this.items});
  final String query;
  final List<api.OrderListItem> items;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visible = q.isEmpty
        ? items
        : items.where((o) {
            return o.id.toLowerCase().contains(q) ||
                o.customerName.toLowerCase().contains(q) ||
                (o.customerPhone ?? '').toLowerCase().contains(q);
          }).toList();

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(
            q.isEmpty
                ? 'No incomplete orders right now.'
                : 'No incomplete orders match "$query"',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final o in visible) ...[
          _OrderRow(order: o),
          const SizedBox(height: AppSpacing.sm + 4),
        ],
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final api.OrderListItem order;

  String _formatTaka(num n) {
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final displayId = order.id.startsWith('#') ? order.id : '#${order.id}';
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xLarge),
      child: InkWell(
        onTap: () => context.push('/orders/${order.id.replaceFirst('#', '')}'),
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        child: Container(
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
          child: Row(
            children: [
              ListThumbnail(
                  imageUrl: null, fallbackInitial: order.customerName),
              const SizedBox(width: AppSpacing.md - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayId,
                          style: AppTypography.h3.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onBackground,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatusPill(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerName.isEmpty
                          ? '(no name)'
                          : order.customerName,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.outline,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '৳ ${_formatTaka(order.total)}',
                style: AppTypography.h3.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'pending' => (
          AppColors.warningContainer,
          AppColors.onWarningContainer,
          'Pending',
        ),
      'processing' => (
          AppColors.infoContainer,
          AppColors.onInfoContainer,
          'Processing',
        ),
      'on_hold' => (
          AppColors.surfaceContainer,
          AppColors.onSurfaceVariant,
          'On Hold',
        ),
      'confirmed' => (
          AppColors.successContainer,
          AppColors.onSuccessContainer,
          'Confirmed',
        ),
      _ => (
          AppColors.surfaceContainer,
          AppColors.onSurfaceVariant,
          status,
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
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}
