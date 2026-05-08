import 'package:akhiyan_admin/src/features/orders/presentation/order_detail_screen.dart' show OrderDetailScreen;

enum OrderStatus { pending, confirmed, processing, shipped, delivered, cancelled }

enum PaymentMethod { bkash, nagad, cod, card }

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.timeAgo,
    required this.itemCount,
    required this.payment,
    required this.totalTaka,
    required this.status,
    this.flagged = false,
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final String timeAgo;
  final int itemCount;
  final PaymentMethod payment;
  final num totalTaka;
  final OrderStatus status;
  final bool flagged;
}

class OrderItem {
  const OrderItem({
    required this.name,
    required this.variant,
    required this.qty,
    required this.priceTaka,
  });
  final String name;
  final String variant;
  final int qty;
  final num priceTaka;
}

class OrderTimelineEvent {
  const OrderTimelineEvent({
    required this.label,
    required this.timestamp,
    this.note,
    this.completed = false,
  });
  final String label;
  final String timestamp;
  final String? note;
  final bool completed;
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.discountLabel,
    required this.discountAmount,
    required this.payment,
    required this.paymentLabel,
    required this.paid,
    required this.courier,
    required this.timeline,
  });

  final String id;
  final OrderStatus status;
  final String customerName;
  final String customerPhone;
  final String address;
  final List<OrderItem> items;
  final num subtotal;
  final num shippingFee;
  final String discountLabel;
  final num discountAmount;
  final PaymentMethod payment;
  final String paymentLabel;
  final bool paid;
  final String courier;
  final List<OrderTimelineEvent> timeline;

  num get total => subtotal + shippingFee - discountAmount;
}

/// Placeholder until [OrderDetailScreen] is wired to the live `/orders/:id`
/// endpoint. Returns a thin shell so the screen can still render after a tap.
OrderDetail buildPlaceholderOrderDetail(String id) {
  return OrderDetail(
    id: id,
    status: OrderStatus.processing,
    customerName: '',
    customerPhone: '',
    address: '',
    items: const [],
    subtotal: 0,
    shippingFee: 0,
    discountLabel: '',
    discountAmount: 0,
    payment: PaymentMethod.cod,
    paymentLabel: 'Cash on Delivery',
    paid: false,
    courier: '',
    timeline: const [],
  );
}
