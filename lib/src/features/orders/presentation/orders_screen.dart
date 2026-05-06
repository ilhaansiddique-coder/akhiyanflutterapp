import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/akhiyan_api.dart' as api;
import '../../../core/api/api_providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shell_app_bar.dart';
import '../../../core/widgets/order_status_badge.dart';
import '../../../core/widgets/page_loading_overlay.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/order.dart';

/// Orders list — wired to the live `/orders` endpoint via [ordersListProvider].
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderStatus? _filter;
  String _query = '';

  /// Page number the user just tapped that is currently being fetched.
  int? _loadingPage;

  void _goToPage(int p) {
    setState(() => _loadingPage = p);
    ref.read(ordersListProvider.notifier).goToPage(p);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersListProvider);
    if (!state.loading && _loadingPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(ordersListProvider).loading) {
          setState(() => _loadingPage = null);
        }
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: const AppShellAppBar(),
      body: Column(
        children: [
          // ── Search + filter row ────────────────────────────────────────
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
                      hintText: 'Search orders...',
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
                          color: AppColors.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        borderSide: const BorderSide(
                          color: AppColors.outlineVariant,
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
                const SizedBox(width: AppSpacing.sm + 4),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.tune,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Filter chips ──────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final s in OrderStatus.values)
                  _FilterChip(
                    label: _statusLabel(s),
                    selected: _filter == s,
                    onTap: () => setState(() => _filter = s),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // ── Order cards ───────────────────────────────────────────────
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
                        _OrderCardSkeleton(),
                        SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  );
                }
                if (state.error != null && state.items.isEmpty) {
                  return _ErrorView(
                    message: _describeError(state.error!),
                    onRetry: () =>
                        ref.read(ordersListProvider.notifier).refresh(),
                  );
                }
                final visible = state.items.where((o) {
                  if (_filter != null &&
                      parseOrderStatus(o.status) != _filter) {
                    return false;
                  }
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  return o.id.toLowerCase().contains(q) ||
                      o.customerName.toLowerCase().contains(q);
                }).toList();
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      state.items.isEmpty
                          ? 'No orders yet'
                          : 'No orders match your filters',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final isPageSwitching =
                    state.loading && state.items.isNotEmpty;
                final list = RefreshIndicator(
                  onRefresh: () =>
                      ref.read(ordersListProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    children: [
                      for (var i = 0; i < visible.length; i++) ...[
                        _OrderCard(
                          order: visible[i],
                          onTap: () => context.push(
                            '/orders/${Uri.encodeComponent(visible[i].id)}',
                          ),
                        ),
                        if (i != visible.length - 1)
                          const SizedBox(height: AppSpacing.md),
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
                        targetPage: _loadingPage ?? state.currentPage,
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

  String _statusLabel(OrderStatus s) => switch (s) {
        OrderStatus.pending => 'Pending',
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.processing => 'Processing',
        OrderStatus.shipped => 'Shipped',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };
}

String _describeError(Object e) {
  if (e is api.ApiException) return e.message;
  if (e is api.NetworkException) return 'No internet connection';
  return 'Could not load orders';
}

/// String → enum mapping shared with the badge widget.
OrderStatus parseOrderStatus(String s) {
  switch (s.toLowerCase()) {
    case 'pending':
      return OrderStatus.pending;
    case 'confirmed':
      return OrderStatus.confirmed;
    case 'processing':
      return OrderStatus.processing;
    case 'shipped':
      return OrderStatus.shipped;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
    case 'canceled':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.pending;
  }
}

PaymentMethod _parsePayment(String s) {
  switch (s.toLowerCase()) {
    case 'bkash':
      return PaymentMethod.bkash;
    case 'nagad':
      return PaymentMethod.nagad;
    case 'card':
      return PaymentMethod.card;
    case 'cod':
    default:
      return PaymentMethod.cod;
  }
}

String _timeAgo(DateTime? when) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) {
    return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays < 2) return 'Yesterday';
  if (diff.inDays < 30) return '${diff.inDays} days ago';
  return '${(diff.inDays / 30).floor()} months ago';
}

// ─── Filter chip ────────────────────────────────────────────────────────

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
        color: selected ? AppColors.primary : AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.outlineVariant,
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

// ─── Error view ────────────────────────────────────────────────────────

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

// ─── Order card ─────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final api.OrderListItem order;
  final VoidCallback onTap;

  IconData _payIcon(PaymentMethod m) => switch (m) {
        PaymentMethod.bkash || PaymentMethod.nagad =>
          Icons.account_balance_wallet,
        PaymentMethod.cod => Icons.payments,
        PaymentMethod.card => Icons.credit_card,
      };

  String _payLabel(PaymentMethod m) => switch (m) {
        PaymentMethod.bkash => 'bKash',
        PaymentMethod.nagad => 'Nagad',
        PaymentMethod.cod => 'COD',
        PaymentMethod.card => 'Card',
      };

  @override
  Widget build(BuildContext context) {
    final status = parseOrderStatus(order.status);
    final payment = _parsePayment(order.paymentMethod);
    final itemsLabel =
        order.itemCount == 1 ? '1 item' : '${order.itemCount} items';
    final displayId =
        order.id.startsWith('#') ? order.id : '#${order.id}';
    final initial = (order.customerName.isNotEmpty
            ? order.customerName.substring(0, 1)
            : '?')
        .toUpperCase();

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: const Color(0xFFF8F9FC),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  children: [
                    Text(
                      displayId,
                      style: AppTypography.h3.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _timeAgo(order.createdAt),
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                    if (order.flagged)
                      const Icon(
                        Icons.report,
                        size: 18,
                        color: AppColors.error,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OrderStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName.isEmpty
                          ? 'Unknown'
                          : order.customerName,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      order.customerPhone ?? '',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.only(top: AppSpacing.sm + 4),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MetaCol(
                  label: 'ITEMS',
                  child: Text(
                    itemsLabel,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.borderSubtle,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 4,
                  ),
                ),
                _MetaCol(
                  label: 'PAYMENT',
                  child: Row(
                    children: [
                      Icon(
                        _payIcon(payment),
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _payLabel(payment),
                        style: AppTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.outline,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      '৳ ${_formatAmount(order.total)}',
                      style: AppTypography.dataDisplayLg.copyWith(
                        color: AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(num n) {
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _MetaCol extends StatelessWidget {
  const _MetaCol({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.outline,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}

// ─── Order card skeleton (first-load placeholder) ───────────────────────

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          SkeletonBox(width: 40, height: 40, radius: 20),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 160, fontSize: 14),
                SizedBox(height: 6),
                SkeletonText(width: 120, fontSize: 13),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          SkeletonText(width: 60, fontSize: 14),
        ],
      ),
    );
  }
}
