// =============================================================================
// Akhiyan Admin — Flutter API client
// =============================================================================
//
// Single-file client for the mobile admin API at /api/mobile/v1/*. Drop this
// into your Flutter project as `lib/api/akhiyan_api.dart`.
//
// Add to pubspec.yaml:
//   dependencies:
//     http: ^1.2.2
//     flutter_secure_storage: ^9.2.4   # optional — for token persistence
//
// Quick start:
//
//   final api = AkhiyanApi(
//     baseUrl: 'https://akhiyanbd.com/api/mobile/v1',
//     storage: SecureTokenStorage(),       // or InMemoryTokenStorage() for dev
//   );
//   final user = await api.auth.login('admin@akhiyanbd.com', 'password');
//   final dashboard = await api.dashboard.fetch();
//   final orders = await api.orders.list(status: 'pending');
//   final detail = await api.orders.detail(orders.data.first.id);
//
// All methods throw [ApiException] on 4xx/5xx responses. Catch it to show
// errors in your UI. The client auto-refreshes the access token once on 401
// and retries the original request transparently.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// =============================================================================
// Exceptions
// =============================================================================

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;

  ApiException(this.statusCode, this.message, [this.details]);

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidationError => statusCode == 422;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

// =============================================================================
// Token storage — plug in flutter_secure_storage in production
// =============================================================================

abstract class TokenStorage {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> save({required String accessToken, required String refreshToken});
  Future<void> clear();
}

/// Default in-memory storage. Tokens are lost on app restart — fine for
/// development, replace with [SecureTokenStorage] (or your own) in production.
class InMemoryTokenStorage implements TokenStorage {
  String? _access;
  String? _refresh;

  @override
  Future<String?> getAccessToken() async => _access;

  @override
  Future<String?> getRefreshToken() async => _refresh;

  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    _access = accessToken;
    _refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

/// Secure storage adapter — uncomment after adding flutter_secure_storage:
///
/// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
///
/// class SecureTokenStorage implements TokenStorage {
///   final _s = const FlutterSecureStorage();
///   @override Future<String?> getAccessToken() => _s.read(key: 'akhiyan_access');
///   @override Future<String?> getRefreshToken() => _s.read(key: 'akhiyan_refresh');
///   @override
///   Future<void> save({required String accessToken, required String refreshToken}) async {
///     await _s.write(key: 'akhiyan_access', value: accessToken);
///     await _s.write(key: 'akhiyan_refresh', value: refreshToken);
///   }
///   @override
///   Future<void> clear() async {
///     await _s.delete(key: 'akhiyan_access');
///     await _s.delete(key: 'akhiyan_refresh');
///   }
/// }

// =============================================================================
// Pagination wrappers
// =============================================================================

class Pagination {
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  Pagination({required this.page, required this.pageSize, required this.total, required this.totalPages});

  factory Pagination.fromJson(Map<String, dynamic> json) {
    final page = (json['page'] ?? json['current_page'] ?? 1) as int;
    final pageSize = (json['pageSize'] ?? json['per_page'] ?? 20) as int;
    final total = (json['total'] ?? 0) as int;
    final totalPages = (json['totalPages'] ?? json['last_page'] ??
        (pageSize > 0 ? ((total + pageSize - 1) ~/ pageSize) : 1)) as int;
    return Pagination(page: page, pageSize: pageSize, total: total, totalPages: totalPages);
  }
}

// Parses paginated payloads in either Flutter envelope shape
// (`{data, pagination: {...}}`) or Laravel/Next shape (`{data, current_page, ...}`).
Pagination _paginationFrom(Map<String, dynamic> res) {
  final inner = res['pagination'];
  if (inner is Map<String, dynamic>) return Pagination.fromJson(inner);
  return Pagination.fromJson(res);
}

class PaginatedResponse<T> {
  final List<T> data;
  final Pagination pagination;

  PaginatedResponse({required this.data, required this.pagination});
}

// =============================================================================
// Models
// =============================================================================

class AdminUser {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String role;
  final String? avatar;
  final DateTime? createdAt;

  AdminUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    this.avatar,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'].toString(),
        name: (json['name'] ?? json['full_name'] ?? '') as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'admin',
        avatar: (json['avatar'] ?? json['image']) as String?,
        createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      );
}

class LoginResult {
  final String accessToken;
  final String refreshToken;
  final AdminUser user;

  LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
        accessToken: json['token'] as String? ?? 'session',
        refreshToken: json['token'] as String? ?? 'session',
        user: AdminUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class OrderListItem {
  final String id;
  final String customerName;
  final String? customerPhone;
  final double total;
  final String status;
  final String paymentMethod;
  final String? paymentStatus;
  final int? riskScore;
  final bool courierSent;
  final int itemCount;
  final bool flagged;
  final DateTime? createdAt;

  OrderListItem({
    required this.id,
    required this.customerName,
    this.customerPhone,
    required this.total,
    required this.status,
    required this.paymentMethod,
    this.paymentStatus,
    this.riskScore,
    this.courierSent = false,
    this.itemCount = 0,
    this.flagged = false,
    this.createdAt,
  });

  factory OrderListItem.fromJson(Map<String, dynamic> json) {
    // items can come as `_count.items`, `items` array length, or itemCount.
    int itemCount = 0;
    final ic = json['itemCount'] ?? json['item_count'];
    if (ic is int) {
      itemCount = ic;
    } else if (json['items'] is List) {
      itemCount = (json['items'] as List).length;
    } else if (json['_count'] is Map && (json['_count'] as Map)['items'] is int) {
      itemCount = (json['_count'] as Map)['items'] as int;
    }
    final risk = (json['riskScore'] ?? json['risk_score']) as int?;
    return OrderListItem(
      id: (json['id'] ?? '').toString(),
      customerName: (json['customerName'] ?? json['customer_name'] ?? '') as String,
      customerPhone: (json['customerPhone'] ?? json['customer_phone']) as String?,
      total: ((json['total'] as num?) ?? 0).toDouble(),
      status: (json['status'] as String?) ?? 'pending',
      paymentMethod: (json['paymentMethod'] ?? json['payment_method'] ?? 'cod') as String,
      paymentStatus: (json['paymentStatus'] ?? json['payment_status']) as String?,
      riskScore: risk,
      courierSent: (json['courierSent'] ?? json['courier_sent'] ?? false) as bool,
      itemCount: itemCount,
      flagged: (json['flagged'] as bool?) ?? ((risk ?? 0) >= 70),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String? productId;
  final String productName;
  final String? variantId;
  final String? variantLabel;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.productName,
    this.variantId,
    this.variantLabel,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: (json['id'] ?? '').toString(),
        orderId: (json['orderId'] ?? json['order_id'] ?? '').toString(),
        productId: (json['productId'] ?? json['product_id'])?.toString(),
        productName: (json['productName'] ?? json['product_name'] ?? '') as String,
        variantId: (json['variantId'] ?? json['variant_id'])?.toString(),
        variantLabel: (json['variantLabel'] ?? json['variant_label']) as String?,
        quantity: (json['quantity'] as int?) ?? 0,
        price: ((json['price'] as num?) ?? 0).toDouble(),
      );
}

class Order {
  final String id;
  final String? userId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String customerAddress;
  final String? city;
  final String? zipCode;
  final double subtotal;
  final double shippingCost;
  final double discount;
  final double total;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String? transactionId;
  final String? notes;
  final bool courierSent;
  final String? courierType;
  final String? consignmentId;
  final String? courierStatus;
  final int? riskScore;
  final bool flagged;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    this.userId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.customerAddress,
    this.city,
    this.zipCode,
    required this.subtotal,
    required this.shippingCost,
    required this.discount,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.transactionId,
    this.notes,
    this.courierSent = false,
    this.courierType,
    this.consignmentId,
    this.courierStatus,
    this.riskScore,
    this.flagged = false,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: (json['id'] ?? '').toString(),
        userId: (json['userId'] ?? json['user_id'])?.toString(),
        customerName: (json['customerName'] ?? json['customer_name'] ?? '') as String,
        customerPhone: (json['customerPhone'] ?? json['customer_phone'] ?? '') as String,
        customerEmail: (json['customerEmail'] ?? json['customer_email']) as String?,
        customerAddress: (json['customerAddress'] ?? json['customer_address'] ?? '') as String,
        city: json['city'] as String?,
        zipCode: (json['zipCode'] ?? json['zip_code']) as String?,
        subtotal: ((json['subtotal'] as num?) ?? 0).toDouble(),
        shippingCost: ((json['shippingCost'] ?? json['shipping_cost']) as num? ?? 0).toDouble(),
        discount: ((json['discount'] as num?) ?? 0).toDouble(),
        total: ((json['total'] as num?) ?? 0).toDouble(),
        status: (json['status'] as String?) ?? 'pending',
        paymentMethod: (json['paymentMethod'] ?? json['payment_method'] ?? 'cod') as String,
        paymentStatus: (json['paymentStatus'] ?? json['payment_status'] ?? 'unpaid') as String,
        transactionId: (json['transactionId'] ?? json['transaction_id']) as String?,
        notes: json['notes'] as String?,
        courierSent: (json['courierSent'] ?? json['courier_sent'] ?? false) as bool,
        courierType: (json['courierType'] ?? json['courier_type']) as String?,
        consignmentId: (json['consignmentId'] ?? json['consignment_id']) as String?,
        courierStatus: (json['courierStatus'] ?? json['courier_status']) as String?,
        riskScore: (json['riskScore'] ?? json['risk_score']) as int?,
        flagged: (json['flagged'] as bool?) ??
            (((json['riskScore'] ?? json['risk_score']) as int? ?? 0) >= 70),
        createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
        updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
        items: ((json['items'] as List?) ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Product {
  final String id;
  final String name;
  final String slug;
  final String? categoryId;
  final String? brandId;
  final String? description;
  final double price;
  final double? originalPrice;
  final String image;
  final String? images;
  final String? badge;
  final String? weight;
  final int stock;
  final bool? unlimitedStock;
  final int soldCount;
  final bool isActive;
  final bool isFeatured;
  final bool? hasVariations;
  final String? variationType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Optional joined models
  final Map<String, dynamic>? category;
  final Map<String, dynamic>? brand;
  final List<ProductVariant>? variants;

  Product({
    required this.id,
    required this.name,
    required this.slug,
    this.categoryId,
    this.brandId,
    this.description,
    required this.price,
    this.originalPrice,
    required this.image,
    this.images,
    this.badge,
    this.weight,
    this.stock = 0,
    this.unlimitedStock,
    this.soldCount = 0,
    this.isActive = true,
    this.isFeatured = false,
    this.hasVariations,
    this.variationType,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.brand,
    this.variants,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final origPrice = json['originalPrice'] ?? json['original_price'];
    final imagesRaw = json['images'];
    String? images;
    if (imagesRaw is String) {
      images = imagesRaw;
    } else if (imagesRaw is List) {
      images = imagesRaw.join(',');
    }
    return Product(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      categoryId: (json['categoryId'] ?? json['category_id'])?.toString(),
      brandId: (json['brandId'] ?? json['brand_id'])?.toString(),
      description: json['description'] as String?,
      price: ((json['price'] as num?) ?? 0).toDouble(),
      originalPrice: origPrice == null ? null : (origPrice as num).toDouble(),
      image: (json['image'] as String?) ?? '',
      images: images,
      badge: json['badge'] as String?,
      weight: json['weight']?.toString(),
      stock: (json['stock'] as int?) ?? 0,
      unlimitedStock: (json['unlimitedStock'] ?? json['unlimited_stock']) as bool?,
      soldCount: ((json['soldCount'] ?? json['sold_count']) as int?) ?? 0,
      isActive: ((json['isActive'] ?? json['is_active']) as bool?) ?? true,
      isFeatured: ((json['isFeatured'] ?? json['is_featured']) as bool?) ?? false,
      hasVariations: (json['hasVariations'] ?? json['has_variations']) as bool?,
      variationType: (json['variationType'] ?? json['variation_type']) as String?,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
      category: json['category'] as Map<String, dynamic>?,
      brand: json['brand'] as Map<String, dynamic>?,
      variants: (json['variants'] as List?)
          ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProductVariant {
  final String id;
  final String productId;
  final String label;
  final double price;
  final double? originalPrice;
  final String? sku;
  final int stock;
  final bool? unlimitedStock;
  final String? image;
  final int sortOrder;
  final bool isActive;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.label,
    required this.price,
    this.originalPrice,
    this.sku,
    this.stock = 0,
    this.unlimitedStock,
    this.image,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final origPrice = json['originalPrice'] ?? json['original_price'];
    return ProductVariant(
      id: (json['id'] ?? '').toString(),
      productId: (json['productId'] ?? json['product_id'] ?? '').toString(),
      label: (json['label'] as String?) ?? '',
      price: ((json['price'] as num?) ?? 0).toDouble(),
      originalPrice: origPrice == null ? null : (origPrice as num).toDouble(),
      sku: json['sku'] as String?,
      stock: (json['stock'] as int?) ?? 0,
      unlimitedStock: (json['unlimitedStock'] ?? json['unlimited_stock']) as bool?,
      image: json['image'] as String?,
      sortOrder: ((json['sortOrder'] ?? json['sort_order']) as int?) ?? 0,
      isActive: ((json['isActive'] ?? json['is_active']) as bool?) ?? true,
    );
  }
}

class CustomerListItem {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatar;
  final DateTime? createdAt;
  final int ordersCount;
  final double totalSpent;

  CustomerListItem({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatar,
    this.createdAt,
    this.ordersCount = 0,
    this.totalSpent = 0,
  });

  factory CustomerListItem.fromJson(Map<String, dynamic> json) {
    // Customers can come from users table, order rollups, or search endpoint —
    // names live in `name`, `full_name`, `fullName`, or nested under `user`.
    final user = json['user'] as Map<String, dynamic>?;
    final name = (json['name'] ??
        json['full_name'] ??
        json['fullName'] ??
        json['customer_name'] ??
        json['customerName'] ??
        user?['full_name'] ??
        user?['fullName'] ??
        user?['name'] ??
        '') as String;
    return CustomerListItem(
      id: (json['id'] ?? user?['id'] ?? '').toString(),
      name: name,
      email: (json['email'] ?? user?['email']) as String?,
      phone: (json['phone'] ?? json['customer_phone'] ?? user?['phone']) as String?,
      avatar: (json['avatar'] ?? json['image'] ?? user?['image']) as String?,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      ordersCount: ((json['ordersCount'] ?? json['orders_count']) as int?) ?? 0,
      totalSpent: (((json['totalSpent'] ?? json['total_spent']) as num?) ?? 0).toDouble(),
    );
  }
}

class CustomerStats {
  final int ordersCount;
  final double totalSpent;
  final DateTime? lastOrderAt;

  CustomerStats({required this.ordersCount, required this.totalSpent, this.lastOrderAt});

  factory CustomerStats.fromJson(Map<String, dynamic> json) => CustomerStats(
        ordersCount: ((json['ordersCount'] ?? json['orders_count']) as int?) ?? 0,
        totalSpent: (((json['totalSpent'] ?? json['total_spent']) as num?) ?? 0).toDouble(),
        lastOrderAt: _parseDate(json['lastOrderAt'] ?? json['last_order_at']),
      );
}

class CustomerDetail {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? avatar;
  final DateTime? createdAt;
  final CustomerStats stats;
  final List<OrderListItem> orders;

  CustomerDetail({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.avatar,
    this.createdAt,
    required this.stats,
    this.orders = const [],
  });

  factory CustomerDetail.fromJson(Map<String, dynamic> json) => CustomerDetail(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? json['full_name'] ?? json['fullName'] ?? '') as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        avatar: (json['avatar'] ?? json['image']) as String?,
        createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
        stats: CustomerStats.fromJson((json['stats'] as Map<String, dynamic>?) ?? const {}),
        orders: ((json['orders'] as List?) ?? [])
            .map((e) => OrderListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Coupon {
  final String id;
  final String code;
  final String type; // percentage | fixed
  final double value;
  final double minOrderAmount;
  final int? maxUses;
  final int usedCount;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime? createdAt;

  Coupon({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.minOrderAmount = 0,
    this.maxUses,
    this.usedCount = 0,
    this.startsAt,
    this.expiresAt,
    this.isActive = true,
    this.createdAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: (json['id'] ?? '').toString(),
        code: (json['code'] as String?) ?? '',
        type: (json['type'] as String?) ?? 'percentage',
        value: ((json['value'] as num?) ?? 0).toDouble(),
        minOrderAmount: (((json['minOrderAmount'] ?? json['min_order_amount']) as num?) ?? 0).toDouble(),
        maxUses: (json['maxUses'] ?? json['max_uses']) as int?,
        usedCount: ((json['usedCount'] ?? json['used_count']) as int?) ?? 0,
        startsAt: _parseDate(json['startsAt'] ?? json['starts_at']),
        expiresAt: _parseDate(json['expiresAt'] ?? json['expires_at']),
        isActive: ((json['isActive'] ?? json['is_active']) as bool?) ?? true,
        createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      );
}

class FlashSale {
  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;
  final int productCount;
  final String state; // live | scheduled | ended | inactive
  final DateTime? createdAt;

  FlashSale({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    this.productCount = 0,
    required this.state,
    this.createdAt,
  });

  factory FlashSale.fromJson(Map<String, dynamic> json) => FlashSale(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] as String?) ?? '',
        startsAt: _parseDate(json['startsAt'] ?? json['starts_at']) ?? DateTime.now(),
        endsAt: _parseDate(json['endsAt'] ?? json['ends_at']) ?? DateTime.now(),
        isActive: ((json['isActive'] ?? json['is_active']) as bool?) ?? true,
        productCount: ((json['productCount'] ?? json['product_count']) as int?) ?? 0,
        state: (json['state'] as String?) ?? 'inactive',
        createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      );
}

class Shortlink {
  final String id;
  final String slug;
  final String targetUrl;
  final int hits;
  final bool isActive;
  final DateTime? createdAt;
  final int sevenDayClicks;
  final List<int> sparkline;

  Shortlink({
    required this.id,
    required this.slug,
    required this.targetUrl,
    this.hits = 0,
    this.isActive = true,
    this.createdAt,
    this.sevenDayClicks = 0,
    this.sparkline = const [],
  });

  factory Shortlink.fromJson(Map<String, dynamic> json) => Shortlink(
        id: (json['id'] ?? '').toString(),
        slug: json['slug'] as String,
        targetUrl: json['targetUrl'] as String,
        hits: json['hits'] as int? ?? 0,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: _parseDate(json['createdAt']),
        sevenDayClicks: json['sevenDayClicks'] as int? ?? 0,
        sparkline: ((json['sparkline'] as List?) ?? []).map((e) => e as int).toList(),
      );
}

class ShortlinkStats {
  final int totalClicks;
  final int last30Days;
  final Map<String, int> sourceBreakdown;
  final Map<String, int> countryBreakdown;
  final List<DailyClicks> daily;

  ShortlinkStats({
    required this.totalClicks,
    required this.last30Days,
    required this.sourceBreakdown,
    required this.countryBreakdown,
    required this.daily,
  });

  factory ShortlinkStats.fromJson(Map<String, dynamic> json) => ShortlinkStats(
        totalClicks: json['totalClicks'] as int,
        last30Days: json['last30Days'] as int,
        sourceBreakdown: Map<String, int>.from(json['sourceBreakdown'] as Map),
        countryBreakdown: Map<String, int>.from(json['countryBreakdown'] as Map),
        daily: ((json['daily'] as List?) ?? [])
            .map((e) => DailyClicks.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DailyClicks {
  final String date;
  final int count;
  DailyClicks({required this.date, required this.count});
  factory DailyClicks.fromJson(Map<String, dynamic> json) =>
      DailyClicks(date: json['date'] as String, count: json['count'] as int);
}

class AdminBanner {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? buttonText;
  final String? buttonUrl;
  final String? image;
  final String? gradient;
  final String? emoji;
  final String position;
  final int sortOrder;
  final bool isActive;

  AdminBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.buttonText,
    this.buttonUrl,
    this.image,
    this.gradient,
    this.emoji,
    this.position = 'hero',
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory AdminBanner.fromJson(Map<String, dynamic> json) => AdminBanner(
        id: (json['id'] ?? '').toString(),
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        description: json['description'] as String?,
        buttonText: json['buttonText'] as String?,
        buttonUrl: json['buttonUrl'] as String?,
        image: json['image'] as String?,
        gradient: json['gradient'] as String?,
        emoji: json['emoji'] as String?,
        position: json['position'] as String? ?? 'hero',
        sortOrder: json['sortOrder'] as int? ?? 0,
        isActive: json['isActive'] as bool? ?? true,
      );
}

class BlockedIp {
  final String id;
  final String ipAddress;
  final String? reason;
  final DateTime? createdAt;

  BlockedIp({required this.id, required this.ipAddress, this.reason, this.createdAt});

  factory BlockedIp.fromJson(Map<String, dynamic> json) => BlockedIp(
        id: (json['id'] ?? '').toString(),
        ipAddress: json['ipAddress'] as String,
        reason: json['reason'] as String?,
        createdAt: _parseDate(json['createdAt']),
      );
}

class BlockedDevice {
  final String id;
  final String fpHash;
  final String? lastIp;
  final String? platform;
  final String? blockReason;
  final DateTime? blockedAt;
  final int seenCount;
  final int riskScore;

  BlockedDevice({
    required this.id,
    required this.fpHash,
    this.lastIp,
    this.platform,
    this.blockReason,
    this.blockedAt,
    this.seenCount = 0,
    this.riskScore = 0,
  });

  factory BlockedDevice.fromJson(Map<String, dynamic> json) => BlockedDevice(
        id: (json['id'] ?? '').toString(),
        fpHash: json['fpHash'] as String,
        lastIp: json['lastIp'] as String?,
        platform: json['platform'] as String?,
        blockReason: json['blockReason'] as String?,
        blockedAt: _parseDate(json['blockedAt']),
        seenCount: json['seenCount'] as int? ?? 0,
        riskScore: json['riskScore'] as int? ?? 0,
      );
}

class FlaggedOrder {
  final String id;
  final String customerName;
  final String customerPhone;
  final double total;
  final String status;
  final int? riskScore;
  final String? ip;
  final int? fpSeenCount;
  final String reason;
  final DateTime? createdAt;

  FlaggedOrder({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.total,
    required this.status,
    this.riskScore,
    this.ip,
    this.fpSeenCount,
    required this.reason,
    this.createdAt,
  });

  factory FlaggedOrder.fromJson(Map<String, dynamic> json) => FlaggedOrder(
        id: (json['id'] ?? '').toString(),
        customerName: json['customerName'] as String,
        customerPhone: json['customerPhone'] as String,
        total: (json['total'] as num).toDouble(),
        status: json['status'] as String,
        riskScore: json['riskScore'] as int?,
        ip: json['ip'] as String?,
        fpSeenCount: json['fpSeenCount'] as int?,
        reason: json['reason'] as String,
        createdAt: _parseDate(json['createdAt']),
      );
}

class StaffMember {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String role;
  final String? avatar;
  final DateTime? createdAt;

  StaffMember({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    this.avatar,
    this.createdAt,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: (json['id'] ?? '').toString(),
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String,
        avatar: json['avatar'] as String?,
        createdAt: _parseDate(json['createdAt']),
      );
}

class InventoryItem {
  final String id;
  final String name;
  final String slug;
  final String image;
  final int stock;
  final bool? unlimitedStock;
  final int soldCount;
  final double price;
  final bool? hasVariations;
  final String level; // unlimited | critical | low | ok
  final List<ProductVariant> variants;

  InventoryItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.image,
    required this.stock,
    this.unlimitedStock,
    this.soldCount = 0,
    required this.price,
    this.hasVariations,
    required this.level,
    this.variants = const [],
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: (json['id'] ?? '').toString(),
        name: json['name'] as String,
        slug: json['slug'] as String,
        image: json['image'] as String,
        stock: json['stock'] as int,
        unlimitedStock: json['unlimitedStock'] as bool?,
        soldCount: json['soldCount'] as int? ?? 0,
        price: (json['price'] as num).toDouble(),
        hasVariations: json['hasVariations'] as bool?,
        level: json['level'] as String,
        variants: ((json['variants'] as List?) ?? [])
            .map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class InventorySummary {
  final int criticalCount;
  final int lowThreshold;
  InventorySummary({required this.criticalCount, required this.lowThreshold});
  factory InventorySummary.fromJson(Map<String, dynamic> json) => InventorySummary(
        criticalCount: json['criticalCount'] as int,
        lowThreshold: json['lowThreshold'] as int,
      );
}

class InventoryResult {
  final List<InventoryItem> data;
  final Pagination pagination;
  final InventorySummary summary;
  InventoryResult({required this.data, required this.pagination, required this.summary});
}

// --- Dashboard ---

class StatCard {
  final num value;
  final int? deltaPct;
  StatCard({required this.value, this.deltaPct});
  factory StatCard.fromJson(Map<String, dynamic> json) => StatCard(
        value: json['value'] as num,
        deltaPct: json['deltaPct'] as int?,
      );
}

class DashboardCards {
  final StatCard todayOrders;
  final StatCard todayRevenue;
  final StatCard pendingOrders;
  final StatCard lowStockItems;

  DashboardCards({
    required this.todayOrders,
    required this.todayRevenue,
    required this.pendingOrders,
    required this.lowStockItems,
  });

  factory DashboardCards.fromJson(Map<String, dynamic> json) => DashboardCards(
        todayOrders: StatCard.fromJson(json['todayOrders'] as Map<String, dynamic>),
        todayRevenue: StatCard.fromJson(json['todayRevenue'] as Map<String, dynamic>),
        pendingOrders: StatCard.fromJson(json['pendingOrders'] as Map<String, dynamic>),
        lowStockItems: StatCard.fromJson(json['lowStockItems'] as Map<String, dynamic>),
      );
}

class TopProductSummary {
  final String id;
  final String name;
  final String slug;
  final String image;
  final int soldCount;
  final double price;

  TopProductSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.image,
    required this.soldCount,
    required this.price,
  });

  factory TopProductSummary.fromJson(Map<String, dynamic> json) => TopProductSummary(
        id: (json['id'] ?? '').toString(),
        name: json['name'] as String,
        slug: json['slug'] as String,
        image: json['image'] as String,
        soldCount: json['soldCount'] as int? ?? 0,
        price: (json['price'] as num).toDouble(),
      );
}

class DashboardData {
  final DashboardCards cards;
  final int flaggedOrdersCount;
  final List<OrderListItem> recentOrders;
  final List<TopProductSummary> topProducts;

  DashboardData({
    required this.cards,
    required this.flaggedOrdersCount,
    required this.recentOrders,
    required this.topProducts,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    // Backend returns flat stats: {"stats": {"today_orders": 0, ...}, "recent_orders": []}
    final stats = (json['stats'] as Map<String, dynamic>?) ?? json['cards'] as Map<String, dynamic>? ?? {};
    final cards = DashboardCards(
      todayOrders: StatCard(value: (stats['today_orders'] ?? stats['todayOrders'] ?? 0) as num),
      todayRevenue: StatCard(value: (stats['today_revenue'] ?? stats['todayRevenue'] ?? 0) as num),
      pendingOrders: StatCard(value: (stats['pending_orders'] ?? stats['pendingOrders'] ?? 0) as num),
      lowStockItems: StatCard(value: (stats['low_stock_items'] ?? stats['lowStockItems'] ?? 0) as num),
    );
    final recent = (json['recent_orders'] ?? json['recentOrders'] ?? []) as List;
    final top = (json['top_products'] ?? json['topProducts'] ?? []) as List;
    return DashboardData(
      cards: cards,
      flaggedOrdersCount: (json['flagged_orders_count'] ?? json['flaggedOrdersCount'] ?? 0) as int,
      recentOrders: recent.map((e) => OrderListItem.fromJson(e as Map<String, dynamic>)).toList(),
      topProducts: top.map((e) => TopProductSummary.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

// --- Analytics ---

class AnalyticsStats {
  final int orders;
  final double revenue;
  final double avgOrderValue;
  final double returnRate;

  AnalyticsStats({
    required this.orders,
    required this.revenue,
    required this.avgOrderValue,
    required this.returnRate,
  });

  factory AnalyticsStats.fromJson(Map<String, dynamic> json) => AnalyticsStats(
        orders: json['orders'] as int,
        revenue: (json['revenue'] as num).toDouble(),
        avgOrderValue: (json['avgOrderValue'] as num).toDouble(),
        returnRate: (json['returnRate'] as num).toDouble(),
      );
}

class RevenuePoint {
  final String date;
  final double revenue;
  final int orders;
  RevenuePoint({required this.date, required this.revenue, required this.orders});
  factory RevenuePoint.fromJson(Map<String, dynamic> json) => RevenuePoint(
        date: json['date'] as String,
        revenue: (json['revenue'] as num).toDouble(),
        orders: json['orders'] as int,
      );
}

class TopProductAnalytics {
  final int? productId;
  final String name;
  final String? image;
  final String? slug;
  final int unitsSold;
  final double revenue;

  TopProductAnalytics({
    this.productId,
    required this.name,
    this.image,
    this.slug,
    required this.unitsSold,
    required this.revenue,
  });

  factory TopProductAnalytics.fromJson(Map<String, dynamic> json) => TopProductAnalytics(
        productId: json['productId'] as int?,
        name: json['name'] as String,
        image: json['image'] as String?,
        slug: json['slug'] as String?,
        unitsSold: json['unitsSold'] as int,
        revenue: (json['revenue'] as num).toDouble(),
      );
}

class TrafficSource {
  final String source;
  final int clicks;
  TrafficSource({required this.source, required this.clicks});
  factory TrafficSource.fromJson(Map<String, dynamic> json) =>
      TrafficSource(source: json['source'] as String, clicks: json['clicks'] as int);
}

class AnalyticsData {
  final String period;
  final DateTime from;
  final DateTime to;
  final AnalyticsStats stats;
  final List<RevenuePoint> revenueChart;
  final List<TopProductAnalytics> topProducts;
  final Map<String, int> statusBreakdown;
  final List<TrafficSource> trafficSources;

  AnalyticsData({
    required this.period,
    required this.from,
    required this.to,
    required this.stats,
    required this.revenueChart,
    required this.topProducts,
    required this.statusBreakdown,
    required this.trafficSources,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    final range = json['range'] as Map<String, dynamic>;
    return AnalyticsData(
      period: json['period'] as String,
      from: DateTime.parse(range['from'] as String),
      to: DateTime.parse(range['to'] as String),
      stats: AnalyticsStats.fromJson(json['stats'] as Map<String, dynamic>),
      revenueChart: ((json['revenueChart'] as List?) ?? [])
          .map((e) => RevenuePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      topProducts: ((json['topProducts'] as List?) ?? [])
          .map((e) => TopProductAnalytics.fromJson(e as Map<String, dynamic>))
          .toList(),
      statusBreakdown: Map<String, int>.from(json['statusBreakdown'] as Map),
      trafficSources: ((json['trafficSources'] as List?) ?? [])
          .map((e) => TrafficSource.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// =============================================================================
// API client — top-level facade
// =============================================================================

class AkhiyanApi {
  final String baseUrl;
  final TokenStorage _storage;
  final http.Client _http;

  /// Called whenever both refresh and access tokens are invalid — your app
  /// should navigate to the login screen.
  void Function()? onAuthExpired;

  late final AuthApi auth;
  late final DashboardApi dashboard;
  late final OrdersApi orders;
  late final ProductsApi products;
  late final CustomersApi customers;
  late final InventoryApi inventory;
  late final CouponsApi coupons;
  late final FlashSalesApi flashSales;
  late final ShortlinksApi shortlinks;
  late final AnalyticsApi analytics;
  late final BannersApi banners;
  late final FraudApi fraud;
  late final StaffApi staff;

  AkhiyanApi({
    required this.baseUrl,
    TokenStorage? storage,
    http.Client? httpClient,
    this.onAuthExpired,
  })  : _storage = storage ?? InMemoryTokenStorage(),
        _http = httpClient ?? http.Client() {
    auth = AuthApi(this);
    dashboard = DashboardApi(this);
    orders = OrdersApi(this);
    products = ProductsApi(this);
    customers = CustomersApi(this);
    inventory = InventoryApi(this);
    coupons = CouponsApi(this);
    flashSales = FlashSalesApi(this);
    shortlinks = ShortlinksApi(this);
    analytics = AnalyticsApi(this);
    banners = BannersApi(this);
    fraud = FraudApi(this);
    staff = StaffApi(this);
  }

  TokenStorage get storage => _storage;

  Future<bool> get isLoggedIn async => (await _storage.getAccessToken()) != null;

  void close() => _http.close();

  /// Internal: low-level request with auto-refresh on 401. Returns the parsed
  /// `data` field of the `{ data, pagination?, ... }` envelope, or the raw
  /// JSON map if there's no `data` key (rare).
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool retried = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final access = await _storage.getAccessToken();
    if (access != null) headers['Authorization'] = 'Bearer $access';

    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await _http.get(uri, headers: headers);
          break;
        case 'POST':
          res = await _http.post(uri, headers: headers, body: body == null ? null : jsonEncode(body));
          break;
        case 'PATCH':
          res = await _http.patch(uri, headers: headers, body: body == null ? null : jsonEncode(body));
          break;
        case 'PUT':
          res = await _http.put(uri, headers: headers, body: body == null ? null : jsonEncode(body));
          break;
        case 'DELETE':
          res = await _http.delete(uri, headers: headers);
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } catch (e) {
      throw NetworkException(e.toString());
    }

    // Auto-refresh once on 401
    if (res.statusCode == 401 && !retried && path != '/auth/refresh' && path != '/auth/login') {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return request(method, path, body: body, query: query, retried: true);
      } else {
        await _storage.clear();
        onAuthExpired?.call();
      }
    }

    Map<String, dynamic> json;
    if (res.body.isEmpty) {
      json = {};
    } else {
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw ApiException(res.statusCode, 'Server returned invalid JSON');
      }
    }

    if (res.statusCode >= 400) {
      final message = (json['message'] as String?) ?? (json['error'] as String?) ?? 'Request failed';
      throw ApiException(
        res.statusCode,
        message,
        json['errors'] as Map<String, dynamic>? ?? json['details'] as Map<String, dynamic>?,
      );
    }

    return json;
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final uri = Uri.parse('$baseUrl/auth/refresh');
      final res = await _http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (res.statusCode != 200) return false;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      await _storage.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

// =============================================================================
// Auth
// =============================================================================

class AuthApi {
  final AkhiyanApi _api;
  AuthApi(this._api);

  Future<AdminUser> login(String email, String password) async {
    final res = await _api.request('POST', '/auth/login', body: {
      'email': email,
      'password': password,
    });
    print('LOGIN RESPONSE: $res');
    try {
      final result = LoginResult.fromJson(res as Map<String, dynamic>);
      await _api._storage.save(accessToken: result.accessToken, refreshToken: result.refreshToken);
      return result.user;
    } catch (e) {
      print('LOGIN PARSE ERROR: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _api.request('POST', '/auth/logout');
    } catch (_) {
      // Logout is best-effort; clear local tokens regardless.
    }
    await _api._storage.clear();
  }

  Future<AdminUser> me() async {
    final res = await _api.request('GET', '/auth/me');
    return AdminUser.fromJson(res['data'] as Map<String, dynamic>);
  }
}

// =============================================================================
// Dashboard
// =============================================================================

class DashboardApi {
  final AkhiyanApi _api;
  DashboardApi(this._api);

  Future<DashboardData> fetch() async {
    final res = await _api.request('GET', '/dashboard');
    return DashboardData.fromJson(res['data'] as Map<String, dynamic>);
  }
}

// =============================================================================
// Orders
// =============================================================================

class OrdersApi {
  final AkhiyanApi _api;
  OrdersApi(this._api);

  Future<PaginatedResponse<OrderListItem>> list({
    String? q,
    String? status,
    bool? flagged,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _api.request('GET', '/orders', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (status != null && status.isNotEmpty) 'status': status,
      if (flagged == true) 'flagged': 'true',
      'page': '$page',
      'pageSize': '$pageSize',
      'per_page': '$pageSize',
    });
    return PaginatedResponse<OrderListItem>(
      data: (res['data'] as List).map((e) => OrderListItem.fromJson(e as Map<String, dynamic>)).toList(),
      pagination: _paginationFrom(res),
    );
  }

  Future<Order> detail(int id) async {
    final res = await _api.request('GET', '/orders/$id');
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> updateStatus(int id, {String? status, String? paymentStatus, String? notes}) async {
    final res = await _api.request('PATCH', '/orders/$id', body: {
      'status': ?status,
      'paymentStatus': ?paymentStatus,
      'notes': ?notes,
    });
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> dispatchToCourier(int id, {required String courier, double? weight, String? instructions}) async {
    final res = await _api.request('POST', '/orders/$id/courier', body: {
      'courier': courier,
      'weight': ?weight,
      'instructions': ?instructions,
    });
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> cancel(int id, {String? reason}) async {
    final res = await _api.request('POST', '/orders/$id/cancel', body: {
      'reason': ?reason,
    });
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> flag(int id, {String? reason}) async {
    final res = await _api.request('POST', '/orders/$id/flag', body: {
      'reason': ?reason,
    });
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> clearFlag(int id) async {
    final res = await _api.request('DELETE', '/orders/$id/flag');
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }
}

// =============================================================================
// Products
// =============================================================================

class ProductsApi {
  final AkhiyanApi _api;
  ProductsApi(this._api);

  Future<PaginatedResponse<Product>> list({
    String? q,
    String? status, // active | draft
    String? stockFilter, // low | out
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _api.request('GET', '/products', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (status != null && status.isNotEmpty) 'status': status,
      if (stockFilter != null && stockFilter.isNotEmpty) 'stockFilter': stockFilter,
      'page': '$page',
      'pageSize': '$pageSize',
      'per_page': '$pageSize',
    });
    return PaginatedResponse<Product>(
      data: (res['data'] as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList(),
      pagination: _paginationFrom(res),
    );
  }

  Future<Product> detail(int id) async {
    final res = await _api.request('GET', '/products/$id');
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Product> create(Map<String, dynamic> input) async {
    final res = await _api.request('POST', '/products', body: input);
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Product> update(int id, Map<String, dynamic> patch) async {
    final res = await _api.request('PATCH', '/products/$id', body: patch);
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.request('DELETE', '/products/$id');
  }

  Future<Map<String, dynamic>> setStock(int id, {int? stock, int? delta}) async {
    assert(stock != null || delta != null, 'Provide stock (absolute) or delta (relative)');
    final res = await _api.request('PATCH', '/products/$id/stock', body: {
      'stock': ?stock,
      'delta': ?delta,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<ProductVariant>> listVariants(int productId) async {
    final res = await _api.request('GET', '/products/$productId/variants');
    return (res['data'] as List).map((e) => ProductVariant.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ProductVariant> createVariant(int productId, Map<String, dynamic> input) async {
    final res = await _api.request('POST', '/products/$productId/variants', body: input);
    return ProductVariant.fromJson(res['data'] as Map<String, dynamic>);
  }
}

// =============================================================================
// Customers
// =============================================================================

class CustomersApi {
  final AkhiyanApi _api;
  CustomersApi(this._api);

  Future<PaginatedResponse<CustomerListItem>> list({String? q, int page = 1, int pageSize = 20}) async {
    final res = await _api.request('GET', '/customers', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      'page': '$page',
      'pageSize': '$pageSize',
    });
    return PaginatedResponse<CustomerListItem>(
      data: (res['data'] as List).map((e) => CustomerListItem.fromJson(e as Map<String, dynamic>)).toList(),
      pagination: _paginationFrom(res),
    );
  }

  Future<CustomerDetail> detail(int id) async {
    final res = await _api.request('GET', '/customers/$id');
    return CustomerDetail.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> block(int id) async {
    await _api.request('POST', '/customers/$id/block');
  }

  Future<void> unblock(int id) async {
    await _api.request('DELETE', '/customers/$id/block');
  }
}

// =============================================================================
// Inventory
// =============================================================================

class InventoryApi {
  final AkhiyanApi _api;
  InventoryApi(this._api);

  Future<InventoryResult> list({String? stockFilter, String? q, int page = 1, int pageSize = 50}) async {
    final res = await _api.request('GET', '/inventory', query: {
      if (stockFilter != null && stockFilter.isNotEmpty) 'stockFilter': stockFilter,
      if (q != null && q.isNotEmpty) 'q': q,
      'page': '$page',
      'pageSize': '$pageSize',
    });
    return InventoryResult(
      data: (res['data'] as List).map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList(),
      pagination: _paginationFrom(res),
      summary: InventorySummary.fromJson(res['summary'] as Map<String, dynamic>),
    );
  }

  /// Convenience pass-through to `products.setStock` for the inline +/- buttons.
  Future<Map<String, dynamic>> adjust(int productId, {int? stock, int? delta}) =>
      _api.products.setStock(productId, stock: stock, delta: delta);
}

// =============================================================================
// Coupons
// =============================================================================

class CouponsApi {
  final AkhiyanApi _api;
  CouponsApi(this._api);

  Future<List<Coupon>> list({bool? active}) async {
    final res = await _api.request('GET', '/coupons', query: {
      if (active != null) 'active': active.toString(),
    });
    return (res['data'] as List).map((e) => Coupon.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Coupon> detail(int id) async {
    final res = await _api.request('GET', '/coupons/$id');
    return Coupon.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Coupon> create({
    required String code,
    required String type,
    required double value,
    double minOrderAmount = 0,
    int? maxUses,
    DateTime? startsAt,
    DateTime? expiresAt,
    bool isActive = true,
  }) async {
    final res = await _api.request('POST', '/coupons', body: {
      'code': code,
      'type': type,
      'value': value,
      'minOrderAmount': minOrderAmount,
      'maxUses': ?maxUses,
      if (startsAt != null) 'startsAt': startsAt.toUtc().toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      'isActive': isActive,
    });
    return Coupon.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Coupon> update(int id, Map<String, dynamic> patch) async {
    final res = await _api.request('PATCH', '/coupons/$id', body: patch);
    return Coupon.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.request('DELETE', '/coupons/$id');
  }
}

// =============================================================================
// Flash Sales
// =============================================================================

class FlashSalesApi {
  final AkhiyanApi _api;
  FlashSalesApi(this._api);

  Future<List<FlashSale>> list() async {
    final res = await _api.request('GET', '/flash-sales');
    return (res['data'] as List).map((e) => FlashSale.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> detail(int id) async {
    final res = await _api.request('GET', '/flash-sales/$id');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create({
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    bool isActive = true,
    List<int>? productIds,
  }) async {
    final res = await _api.request('POST', '/flash-sales', body: {
      'title': title,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
      'isActive': isActive,
      'productIds': ?productIds,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> patch) async {
    final res = await _api.request('PATCH', '/flash-sales/$id', body: patch);
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> delete(int id) async {
    await _api.request('DELETE', '/flash-sales/$id');
  }
}

// =============================================================================
// Shortlinks
// =============================================================================

class ShortlinksApi {
  final AkhiyanApi _api;
  ShortlinksApi(this._api);

  Future<List<Shortlink>> list() async {
    final res = await _api.request('GET', '/shortlinks');
    return (res['data'] as List).map((e) => Shortlink.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> detail(int id) async {
    final res = await _api.request('GET', '/shortlinks/$id');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Shortlink> create({required String slug, required String targetUrl, bool isActive = true}) async {
    final res = await _api.request('POST', '/shortlinks', body: {
      'slug': slug,
      'targetUrl': targetUrl,
      'isActive': isActive,
    });
    return Shortlink.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Shortlink> update(int id, {String? targetUrl, bool? isActive}) async {
    final res = await _api.request('PATCH', '/shortlinks/$id', body: {
      'targetUrl': ?targetUrl,
      'isActive': ?isActive,
    });
    return Shortlink.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.request('DELETE', '/shortlinks/$id');
  }
}

// =============================================================================
// Analytics
// =============================================================================

class AnalyticsApi {
  final AkhiyanApi _api;
  AnalyticsApi(this._api);

  /// `period` is one of: today | 7d | 30d | custom. For `custom`, pass [from] and [to].
  Future<AnalyticsData> fetch({String period = '7d', DateTime? from, DateTime? to}) async {
    final res = await _api.request('GET', '/analytics', query: {
      'period': period,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    });
    return AnalyticsData.fromJson(res['data'] as Map<String, dynamic>);
  }
}

// =============================================================================
// Banners
// =============================================================================

class BannersApi {
  final AkhiyanApi _api;
  BannersApi(this._api);

  Future<List<AdminBanner>> list({String? position}) async {
    final res = await _api.request('GET', '/marketing/banners', query: {
      'position': ?position,
    });
    return (res['data'] as List).map((e) => AdminBanner.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminBanner> create(Map<String, dynamic> input) async {
    final res = await _api.request('POST', '/marketing/banners', body: input);
    return AdminBanner.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<AdminBanner> update(int id, Map<String, dynamic> patch) async {
    final res = await _api.request('PATCH', '/marketing/banners/$id', body: patch);
    return AdminBanner.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.request('DELETE', '/marketing/banners/$id');
  }
}

// =============================================================================
// Fraud
// =============================================================================

class FraudApi {
  final AkhiyanApi _api;
  FraudApi(this._api);

  Future<PaginatedResponse<FlaggedOrder>> flaggedOrders({int page = 1, int pageSize = 20}) async {
    final res = await _api.request('GET', '/fraud/orders', query: {
      'page': '$page',
      'pageSize': '$pageSize',
    });
    return PaginatedResponse<FlaggedOrder>(
      data: (res['data'] as List).map((e) => FlaggedOrder.fromJson(e as Map<String, dynamic>)).toList(),
      pagination: _paginationFrom(res),
    );
  }

  Future<List<BlockedIp>> blockedIps() async {
    final res = await _api.request('GET', '/fraud/blocked-ips');
    return (res['data'] as List).map((e) => BlockedIp.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BlockedIp> blockIp(String ipAddress, {String? reason}) async {
    final res = await _api.request('POST', '/fraud/blocked-ips', body: {
      'ipAddress': ipAddress,
      'reason': ?reason,
    });
    return BlockedIp.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> unblockIp(String ipAddress) async {
    await _api.request('DELETE', '/fraud/blocked-ips', query: {'ip': ipAddress});
  }

  Future<List<BlockedDevice>> blockedDevices() async {
    final res = await _api.request('GET', '/fraud/blocked-devices');
    return (res['data'] as List).map((e) => BlockedDevice.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BlockedDevice> blockDevice(String fpHash, {String? reason}) async {
    final res = await _api.request('POST', '/fraud/blocked-devices', body: {
      'fpHash': fpHash,
      'reason': ?reason,
    });
    return BlockedDevice.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> unblockDevice(String fpHash) async {
    await _api.request('DELETE', '/fraud/blocked-devices', query: {'fpHash': fpHash});
  }
}

// =============================================================================
// Staff
// =============================================================================

class StaffApi {
  final AkhiyanApi _api;
  StaffApi(this._api);

  Future<List<StaffMember>> list() async {
    final res = await _api.request('GET', '/staff');
    return (res['data'] as List).map((e) => StaffMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<StaffMember> create({
    required String name,
    required String email,
    required String password,
    String? phone,
    String role = 'staff',
  }) async {
    final res = await _api.request('POST', '/staff', body: {
      'name': name,
      'email': email,
      'password': password,
      'phone': ?phone,
      'role': role,
    });
    return StaffMember.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<StaffMember> update(int id, {String? name, String? phone, String? role}) async {
    final res = await _api.request('PATCH', '/staff/$id', body: {
      'name': ?name,
      'phone': ?phone,
      'role': ?role,
    });
    return StaffMember.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.request('DELETE', '/staff/$id');
  }
}

// =============================================================================
// Helpers
// =============================================================================

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}
