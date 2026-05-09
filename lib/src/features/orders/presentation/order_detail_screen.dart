import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/errors/error_mapper.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_card.dart';
import 'package:akhiyan_admin/src/core/widgets/notification_bell.dart';
import 'package:akhiyan_admin/src/core/widgets/order_status_badge.dart';
import 'package:akhiyan_admin/src/core/widgets/states/states.dart';
import 'package:akhiyan_admin/src/features/orders/domain/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Live order detail screen. Watches [orderDetailProvider] for the given id,
/// renders loading / error / data states, and exposes actions (mark paid,
/// dispatch courier, flag, cancel) that round-trip via the API and refresh
/// the provider.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrder = ref.watch(orderDetailProvider(orderId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: asyncOrder.when(
          loading: () => Text(
            'Order #$orderId',
            style: AppTypography.h3.copyWith(fontSize: 18),
          ),
          error: (_, _) => Text(
            'Order #$orderId',
            style: AppTypography.h3.copyWith(fontSize: 18),
          ),
          data: (o) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Order #${_shortId(o.id)}',
                style: AppTypography.h3.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 2),
              OrderStatusBadge(status: _mapStatus(o.status)),
            ],
          ),
        ),
        toolbarHeight: 72,
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: asyncOrder.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: describeError(e, fallback: 'Could not load order'),
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
          icon: Icons.cloud_off,
        ),
        data: (o) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(orderDetailProvider(orderId)),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _CustomerCard(order: o),
              const SizedBox(height: AppSpacing.md),
              _ItemsCard(order: o),
              const SizedBox(height: AppSpacing.md),
              _PaymentCard(order: o, orderId: orderId),
              const SizedBox(height: AppSpacing.md),
              _CourierCard(order: o, orderId: orderId),
              const SizedBox(height: AppSpacing.md),
              _TimelineCard(order: o),
              const SizedBox(height: AppSpacing.lg),
              _DangerZone(order: o, orderId: orderId),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mappers ─────────────────────────────────────────────────────────────

/// Backend stores order status as a free-form string. Map to the local
/// enum that the badge widget understands. Unknown values fall through to
/// `processing` so the screen never crashes on a new status the backend
/// adds before the app updates.
OrderStatus _mapStatus(String s) {
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
      return OrderStatus.processing;
  }
}

String _paymentLabel(String method) {
  switch (method.toLowerCase()) {
    case 'cod':
      return 'Cash on Delivery';
    case 'bkash':
      return 'bKash';
    case 'nagad':
      return 'Nagad';
    case 'card':
      return 'Card';
    default:
      return method.isEmpty
          ? 'Unknown'
          : method[0].toUpperCase() + method.substring(1);
  }
}

String _shortId(String id) {
  // Backend ids are UUIDs; show only the first segment in the title so the
  // toolbar doesn't get cut off on phones.
  if (id.length <= 8) return id;
  final dash = id.indexOf('-');
  return dash > 0 ? id.substring(0, dash) : id.substring(0, 8);
}

// ─── Section card shell ──────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ─── Customer card ───────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.order});
  final api.Order order;

  String get _fullAddress {
    final parts = <String>[
      if (order.customerAddress.isNotEmpty) order.customerAddress,
      if ((order.city ?? '').isNotEmpty) order.city!,
      if ((order.zipCode ?? '').isNotEmpty) order.zipCode!,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customer Info',
                style: AppTypography.h3.copyWith(fontSize: 16),
              ),
              const Icon(
                Icons.person_outlined,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            order.customerName.isEmpty ? '—' : order.customerName,
            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(
                Icons.call_outlined,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                order.customerPhone,
                style: AppTypography.bodySm.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          if ((order.customerEmail ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.customerEmail!,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _fullAddress,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
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

// ─── Items + totals card ─────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});
  final api.Order order;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Items',
                  style: AppTypography.h3.copyWith(fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${order.items.length} Items',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (order.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  'No items in this order',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < order.items.length; i++) ...[
              _LineItem(item: order.items[i]),
              if (i < order.items.length - 1) const Divider(height: 1),
            ],
          Container(
            color: AppColors.surfaceContainerLow,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _row('Subtotal', '৳${order.subtotal.toStringAsFixed(0)}'),
                const SizedBox(height: AppSpacing.xs),
                _row(
                  'Shipping Fee',
                  '৳${order.shippingCost.toStringAsFixed(0)}',
                ),
                if (order.discount > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _row(
                    'Discount',
                    '-৳${order.discount.toStringAsFixed(0)}',
                    valueColor: AppColors.error,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: AppTypography.h3.copyWith(fontSize: 18),
                    ),
                    Text(
                      '৳${order.total.toStringAsFixed(0)}',
                      style: AppTypography.dataDisplayLg.copyWith(fontSize: 22),
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

  Widget _row(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodySm.copyWith(
            color: valueColor ?? AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.item});
  final api.OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: const Icon(
              Icons.image_outlined,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: AppTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '৳${item.price.toStringAsFixed(0)}',
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if ((item.variantLabel ?? '').isNotEmpty)
                  Text(
                    item.variantLabel!,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  'Qty: ${item.quantity}',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
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

// ─── Payment card ────────────────────────────────────────────────────────

class _PaymentCard extends ConsumerStatefulWidget {
  const _PaymentCard({required this.order, required this.orderId});
  final api.Order order;
  final String orderId;

  @override
  ConsumerState<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends ConsumerState<_PaymentCard> {
  bool _busy = false;

  Future<void> _markPaid() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(akhiyanApiProvider)
          .orders
          .updateStatus(widget.orderId, paymentStatus: 'paid');
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(ordersListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment marked as paid'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e, fallback: 'Could not load order')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = widget.order.paymentStatus.toLowerCase() == 'paid';
    return _SectionCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _paymentLabel(widget.order.paymentMethod),
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: paid ? AppColors.success : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      paid ? 'Paid' : 'Unpaid',
                      style: AppTypography.bodySm.copyWith(
                        color: paid ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((widget.order.transactionId ?? '').isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          'TXN ${widget.order.transactionId!}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!paid)
            _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _markPaid,
                    child: const Text('Mark Paid'),
                  ),
        ],
      ),
    );
  }
}

// ─── Courier card ────────────────────────────────────────────────────────

class _CourierCard extends ConsumerStatefulWidget {
  const _CourierCard({required this.order, required this.orderId});
  final api.Order order;
  final String orderId;

  @override
  ConsumerState<_CourierCard> createState() => _CourierCardState();
}

class _CourierCardState extends ConsumerState<_CourierCard> {
  bool _busy = false;

  String get _courierLabel {
    final type = widget.order.courierType;
    if (type == null || type.isEmpty) return 'No courier assigned';
    return type[0].toUpperCase() + type.substring(1);
  }

  Future<void> _dispatch() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Choose Courier',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            for (final c in const ['pathao', 'steadfast', 'redx', 'paperfly'])
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(c[0].toUpperCase() + c.substring(1)),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(akhiyanApiProvider)
          .orders
          .dispatchToCourier(widget.orderId, courier: selected);
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(ordersListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent to $selected'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e, fallback: 'Could not load order')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = widget.order.courierSent;
    final consignment = widget.order.consignmentId ?? '';
    final status = widget.order.courierStatus ?? '';
    return _SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: AppColors.primaryFixed,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _courierLabel,
                      style: AppTypography.h3.copyWith(fontSize: 16),
                    ),
                    if (consignment.isNotEmpty)
                      Text(
                        'Consignment: $consignment',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: sent
                      ? AppColors.successContainer
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Text(
                  sent
                      ? (status.isEmpty ? 'Dispatched' : status)
                      : 'Pending Dispatch',
                  style: AppTypography.caption.copyWith(
                    color: sent
                        ? AppColors.onSuccessContainer
                        : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy || sent ? null : _dispatch,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.onPrimary),
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(sent ? 'Already dispatched' : 'Send to courier'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline (synthesised from order metadata) ──────────────────────────

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.order});
  final api.Order order;

  /// The backend doesn't expose an event log yet — synthesise a coarse
  /// timeline from the fields we have so the screen still tells a story.
  /// Replace this with real events once the backend ships them.
  List<OrderTimelineEvent> _events() {
    final fmt = DateFormat('MMM d, h:mm a');
    final created = order.createdAt;
    final updated = order.updatedAt;
    final status = order.status.toLowerCase();
    final paid = order.paymentStatus.toLowerCase() == 'paid';
    final events = <OrderTimelineEvent>[
      OrderTimelineEvent(
        label: 'Order placed',
        timestamp: created != null ? fmt.format(created.toLocal()) : '—',
        completed: true,
      ),
      OrderTimelineEvent(
        label: 'Payment ${paid ? 'received' : 'pending'}',
        timestamp: paid && updated != null ? fmt.format(updated.toLocal()) : '—',
        completed: paid,
      ),
      OrderTimelineEvent(
        label: 'Sent to courier',
        timestamp: order.courierSent && updated != null
            ? fmt.format(updated.toLocal())
            : '—',
        completed: order.courierSent,
      ),
      OrderTimelineEvent(
        label: 'Delivered',
        timestamp: status == 'delivered' && updated != null
            ? fmt.format(updated.toLocal())
            : '—',
        completed: status == 'delivered',
      ),
    ];
    if (status == 'cancelled' || status == 'canceled') {
      events.add(OrderTimelineEvent(
        label: 'Cancelled',
        timestamp: updated != null ? fmt.format(updated.toLocal()) : '—',
        completed: true,
      ));
    }
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final events = _events();
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order History',
            style: AppTypography.h3.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < events.length; i++)
            _TimelineRow(event: events[i], isLast: i == events.length - 1),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});
  final OrderTimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: event.completed
                      ? AppColors.primary
                      : AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: event.completed
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.surfaceContainerHigh,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.label,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: event.completed
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    event.timestamp,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Danger zone (flag / cancel) ─────────────────────────────────────────

class _DangerZone extends ConsumerStatefulWidget {
  const _DangerZone({required this.order, required this.orderId});
  final api.Order order;
  final String orderId;

  @override
  ConsumerState<_DangerZone> createState() => _DangerZoneState();
}

class _DangerZoneState extends ConsumerState<_DangerZone> {
  bool _busy = false;

  Future<String?> _promptReason(String title, String hint) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return reason == null || reason.isEmpty ? null : reason;
  }

  Future<void> _flag() async {
    final reason = await _promptReason(
      'Flag as suspicious',
      'Why are you flagging this order?',
    );
    if (reason == null) return;
    await _run(() async {
      await ref
          .read(akhiyanApiProvider)
          .orders
          .flag(widget.orderId, reason: reason);
    }, 'Order flagged');
  }

  Future<void> _cancel() async {
    final reason = await _promptReason(
      'Cancel order',
      'Reason (visible in audit log)',
    );
    if (reason == null) return;
    await _run(() async {
      await ref
          .read(akhiyanApiProvider)
          .orders
          .cancel(widget.orderId, reason: reason);
    }, 'Order cancelled');
  }

  Future<void> _run(Future<void> Function() action, String successMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(ordersListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e, fallback: 'Could not load order')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = widget.order.status.toLowerCase().startsWith('cancel');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            'DANGER ZONE',
            style: AppTypography.caption.copyWith(
              color: AppColors.outline,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              fontSize: 11,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _flag,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(
                  widget.order.flagged ? 'Re-flag' : 'Flag Suspicious',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy || cancelled ? null : _cancel,
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: Text(cancelled ? 'Cancelled' : 'Cancel Order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
