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

import 'package:akhiyan_admin/src/core/api/secure_token_storage.dart' show SecureTokenStorage;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

// =============================================================================
// Exceptions
// =============================================================================

class ApiException implements Exception {

  ApiException(this.statusCode, this.message, [this.details, this.raw]);
  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;

  /// Raw decoded body of the error response. Kept around for cases like
  /// 422 from Zod-style backends where `details` is structurally
  /// nested ({ items: { _errors: [...] }, ... }) and the flattened
  /// `details` map can't represent it. UIs that want a verbatim dump
  /// (developer-facing error dialogs) can read this directly.
  final Map<String, dynamic>? raw;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidationError => statusCode == 422;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  NetworkException(this.message);
  final String message;
  @override
  String toString() => 'NetworkException: $message';
}

// =============================================================================
// Token storage — plug in flutter_secure_storage in production
// =============================================================================

abstract class TokenStorage {
  Future<String?> getAccessToken();
  Future<void> save({required String accessToken});
  Future<void> clear();
}

/// Default in-memory storage. Tokens are lost on app restart — fine for
/// development, replace with [SecureTokenStorage] (or your own) in production.
class InMemoryTokenStorage implements TokenStorage {
  String? _access;

  @override
  Future<String?> getAccessToken() async => _access;

  @override
  Future<void> save({required String accessToken}) async {
    _access = accessToken;
  }

  @override
  Future<void> clear() async {
    _access = null;
  }
}

// =============================================================================
// Pagination wrappers
// =============================================================================

class Pagination {

  Pagination({required this.page, required this.pageSize, required this.total, required this.totalPages});

  factory Pagination.fromJson(Map<String, dynamic> json) {
    final page = (json['page'] ?? json['current_page'] ?? 1) as int;
    final pageSize = (json['pageSize'] ?? json['per_page'] ?? 20) as int;
    final total = (json['total'] ?? 0) as int;
    final totalPages = (json['totalPages'] ?? json['last_page'] ??
        (pageSize > 0 ? ((total + pageSize - 1) ~/ pageSize) : 1)) as int;
    return Pagination(page: page, pageSize: pageSize, total: total, totalPages: totalPages);
  }
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
}

// Parses paginated payloads in either Flutter envelope shape
// (`{data, pagination: {...}}`) or Laravel/Next shape (`{data, current_page, ...}`).
Pagination _paginationFrom(Map<String, dynamic> res) {
  final inner = res['pagination'];
  if (inner is Map<String, dynamic>) return Pagination.fromJson(inner);
  return Pagination.fromJson(res);
}

class PaginatedResponse<T> {

  PaginatedResponse({required this.data, required this.pagination});
  final List<T> data;
  final Pagination pagination;
}

// =============================================================================
// Models
// =============================================================================

class AdminUser {

  AdminUser({
    required this.id,
    required this.name,
    required this.role, this.email,
    this.phone,
    this.avatar,
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'].toString(),
        name: (json['name'] ?? '') as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'admin',
        avatar: json['avatar'] as String?,
        createdAt: _parseDate(json['createdAt']),
      );
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String role;
  final String? avatar;
  final DateTime? createdAt;

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';
}

class LoginResult {

  LoginResult({
    required this.accessToken,
    required this.user,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
        accessToken: json['token'] as String? ?? 'session',
        user: AdminUser.fromJson(json['user'] as Map<String, dynamic>),
      );
  final String accessToken;
  final AdminUser user;
}

class OrderListItem {

  OrderListItem({
    required this.id,
    required this.customerName,
    required this.total, required this.status, required this.paymentMethod, this.customerPhone,
    this.paymentStatus,
    this.riskScore,
    this.courierSent = false,
    this.itemCount = 0,
    this.flagged = false,
    this.createdAt,
  });

  factory OrderListItem.fromJson(Map<String, dynamic> json) {
    // items can come as `_count.items`, `items` array length, item_count, or itemCount.
    var itemCount = 0;
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
}

/// Filter option for the orders list. Keys are stable backend slugs
/// (e.g. `pending`, `shipped`); labels are human-friendly. Optional
/// hex `color` lets the backend customize chip / badge tint per
/// status without a Flutter release.
class OrderStatusOption {
  const OrderStatusOption({
    required this.key,
    required this.label,
    this.color,
  });

  factory OrderStatusOption.fromJson(Map<String, dynamic> json) =>
      OrderStatusOption(
        key: (json['key'] ?? '').toString(),
        label: (json['label'] ?? json['key'] ?? '').toString(),
        color: json['color'] as String?,
      );

  final String key;
  final String label;
  final String? color;
}

class OrderItem {

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productName, required this.quantity, required this.price, this.productId,
    this.variantId,
    this.variantLabel,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: (json['id'] ?? '').toString(),
        orderId: (json['orderId'] ?? '').toString(),
        productId: json['productId']?.toString(),
        productName: (json['productName'] ?? '') as String,
        variantId: json['variantId']?.toString(),
        variantLabel: json['variantLabel'] as String?,
        quantity: (json['quantity'] as int?) ?? 0,
        price: ((json['price'] as num?) ?? 0).toDouble(),
      );
  final String id;
  final String orderId;
  final String? productId;
  final String productName;
  final String? variantId;
  final String? variantLabel;
  final int quantity;
  final double price;
}

class Order {

  Order({
    required this.id,
    required this.customerName, required this.customerPhone, required this.customerAddress, required this.subtotal, required this.shippingCost, required this.discount, required this.total, required this.status, required this.paymentMethod, required this.paymentStatus, this.userId,
    this.customerEmail,
    this.city,
    this.zipCode,
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
        userId: json['userId']?.toString(),
        customerName: (json['customerName'] ?? '') as String,
        customerPhone: (json['customerPhone'] ?? '') as String,
        customerEmail: json['customerEmail'] as String?,
        customerAddress: (json['customerAddress'] ?? '') as String,
        city: json['city'] as String?,
        zipCode: json['zipCode'] as String?,
        subtotal: ((json['subtotal'] as num?) ?? 0).toDouble(),
        shippingCost: ((json['shippingCost'] as num?) ?? 0).toDouble(),
        discount: ((json['discount'] as num?) ?? 0).toDouble(),
        total: ((json['total'] as num?) ?? 0).toDouble(),
        status: (json['status'] as String?) ?? 'pending',
        paymentMethod: (json['paymentMethod'] ?? 'cod') as String,
        paymentStatus: (json['paymentStatus'] ?? 'unpaid') as String,
        transactionId: json['transactionId'] as String?,
        notes: json['notes'] as String?,
        courierSent: (json['courierSent'] ?? false) as bool,
        courierType: json['courierType'] as String?,
        consignmentId: json['consignmentId'] as String?,
        courierStatus: json['courierStatus'] as String?,
        riskScore: json['riskScore'] as int?,
        flagged: (json['flagged'] as bool?) ??
            ((json['riskScore'] as int? ?? 0) >= 70),
        createdAt: _parseDate(json['createdAt']),
        updatedAt: _parseDate(json['updatedAt']),
        items: ((json['items'] as List?) ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
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
}

class Product {

  Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.price, required this.image, this.categoryId,
    this.brandId,
    this.description,
    this.originalPrice,
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
    final origPrice = json['originalPrice'];
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
      categoryId: json['categoryId']?.toString(),
      brandId: json['brandId']?.toString(),
      description: json['description'] as String?,
      price: ((json['price'] as num?) ?? 0).toDouble(),
      originalPrice: origPrice == null ? null : (origPrice as num).toDouble(),
      image: (json['image'] as String?) ?? '',
      images: images,
      badge: json['badge'] as String?,
      weight: json['weight']?.toString(),
      stock: (json['stock'] as int?) ?? 0,
      unlimitedStock: json['unlimitedStock'] as bool?,
      soldCount: (json['soldCount'] as int?) ?? 0,
      isActive: (json['isActive'] as bool?) ?? true,
      isFeatured: (json['isFeatured'] as bool?) ?? false,
      hasVariations: json['hasVariations'] as bool?,
      variationType: json['variationType'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      category: json['category'] as Map<String, dynamic>?,
      brand: json['brand'] as Map<String, dynamic>?,
      variants: (json['variants'] as List?)
          ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
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
}

class ProductVariant {

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
    final origPrice = json['originalPrice'];
    return ProductVariant(
      id: (json['id'] ?? '').toString(),
      productId: (json['productId'] ?? '').toString(),
      label: (json['label'] as String?) ?? '',
      price: ((json['price'] as num?) ?? 0).toDouble(),
      originalPrice: origPrice == null ? null : (origPrice as num).toDouble(),
      sku: json['sku'] as String?,
      stock: (json['stock'] as int?) ?? 0,
      unlimitedStock: json['unlimitedStock'] as bool?,
      image: json['image'] as String?,
      sortOrder: (json['sortOrder'] as int?) ?? 0,
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }
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
}

class Category {

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.image,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
    this.productsCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] as String?) ?? '',
        slug: (json['slug'] as String?) ?? '',
        image: json['image'] as String?,
        description: json['description'] as String?,
        sortOrder: (json['sortOrder'] ?? json['sort_order'] ?? 0) as int,
        isActive: (json['isActive'] ?? json['is_active'] ?? true) as bool,
        productsCount:
            (json['productsCount'] ?? json['products_count'] ?? 0) as int,
      );
  final String id;
  final String name;
  final String slug;
  final String? image;
  final String? description;
  final int sortOrder;
  final bool isActive;
  final int productsCount;
}

class Brand {

  Brand({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
    this.isActive = true,
    this.productsCount = 0,
  });

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] as String?) ?? '',
        slug: (json['slug'] as String?) ?? '',
        logo: json['logo'] as String?,
        isActive: (json['isActive'] ?? json['is_active'] ?? true) as bool,
        productsCount:
            (json['productsCount'] ?? json['products_count'] ?? 0) as int,
      );
  final String id;
  final String name;
  final String slug;
  final String? logo;
  final bool isActive;
  final int productsCount;
}

class CustomerListItem {

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
    // names live in `name`, `customerName`, or nested under `user`.
    final user = json['user'] as Map<String, dynamic>?;
    final name = (json['name'] ??
        json['customerName'] ??
        user?['name'] ??
        '') as String;
    return CustomerListItem(
      id: (json['id'] ?? user?['id'] ?? '').toString(),
      name: name,
      email: (json['email'] ?? user?['email']) as String?,
      phone: (json['phone'] ?? user?['phone']) as String?,
      avatar: (json['avatar'] ?? user?['avatar']) as String?,
      createdAt: _parseDate(json['createdAt']),
      ordersCount: (json['ordersCount'] as int?) ?? 0,
      totalSpent: ((json['totalSpent'] as num?) ?? 0).toDouble(),
    );
  }
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatar;
  final DateTime? createdAt;
  final int ordersCount;
  final double totalSpent;
}

class CustomerStats {

  CustomerStats({required this.ordersCount, required this.totalSpent, this.lastOrderAt});

  factory CustomerStats.fromJson(Map<String, dynamic> json) => CustomerStats(
        ordersCount: (json['ordersCount'] as int?) ?? 0,
        totalSpent: ((json['totalSpent'] as num?) ?? 0).toDouble(),
        lastOrderAt: _parseDate(json['lastOrderAt']),
      );
  final int ordersCount;
  final double totalSpent;
  final DateTime? lastOrderAt;
}

class CustomerDetail {

  CustomerDetail({
    required this.id,
    required this.name,
    required this.stats, this.email,
    this.phone,
    this.address,
    this.avatar,
    this.createdAt,
    this.orders = const [],
  });

  factory CustomerDetail.fromJson(Map<String, dynamic> json) => CustomerDetail(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '') as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        avatar: json['avatar'] as String?,
        createdAt: _parseDate(json['createdAt']),
        stats: CustomerStats.fromJson((json['stats'] as Map<String, dynamic>?) ?? const {}),
        orders: ((json['orders'] as List?) ?? [])
            .map((e) => OrderListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? avatar;
  final DateTime? createdAt;
  final CustomerStats stats;
  final List<OrderListItem> orders;
}

class Coupon {

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

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: (json['id'] ?? '').toString(),
        code: (json['code'] as String?) ?? '',
        type: (json['type'] as String?) ?? 'percentage',
        value: ((json['value'] as num?) ?? 0).toDouble(),
        minOrderAmount: ((json['minOrderAmount'] as num?) ?? 0).toDouble(),
        maxUses: json['maxUses'] as int?,
        usedCount: (json['usedCount'] as int?) ?? 0,
        startsAt: _parseDate(json['startsAt']),
        expiresAt: _parseDate(json['expiresAt']),
        isActive: (json['isActive'] as bool?) ?? true,
        createdAt: _parseDate(json['createdAt']),
      );
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

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

class FlashSale {

  FlashSale({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    required this.state, this.productCount = 0,
    this.createdAt,
  });

  factory FlashSale.fromJson(Map<String, dynamic> json) => FlashSale(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] as String?) ?? '',
        startsAt: _parseDate(json['startsAt']) ?? DateTime.now(),
        endsAt: _parseDate(json['endsAt']) ?? DateTime.now(),
        isActive: (json['isActive'] as bool?) ?? true,
        productCount: (json['productCount'] as int?) ?? 0,
        state: (json['state'] as String?) ?? 'inactive',
        createdAt: _parseDate(json['createdAt']),
      );
  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;
  final int productCount;
  final String state; // live | scheduled | ended | inactive
  final DateTime? createdAt;
}

class Shortlink {

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
  final String id;
  final String slug;
  final String targetUrl;
  final int hits;
  final bool isActive;
  final DateTime? createdAt;
  final int sevenDayClicks;
  final List<int> sparkline;
}

class AdminBanner {

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
}

class BlockedIp {

  BlockedIp({required this.id, required this.ipAddress, this.reason, this.createdAt});

  factory BlockedIp.fromJson(Map<String, dynamic> json) => BlockedIp(
        id: (json['id'] ?? '').toString(),
        ipAddress: json['ipAddress'] as String,
        reason: json['reason'] as String?,
        createdAt: _parseDate(json['createdAt']),
      );
  final String id;
  final String ipAddress;
  final String? reason;
  final DateTime? createdAt;
}

class BlockedDevice {

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
  final String id;
  final String fpHash;
  final String? lastIp;
  final String? platform;
  final String? blockReason;
  final DateTime? blockedAt;
  final int seenCount;
  final int riskScore;
}

class FlaggedOrder {

  FlaggedOrder({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.total,
    required this.status,
    required this.reason, this.riskScore,
    this.ip,
    this.fpSeenCount,
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
}

class StaffMember {

  StaffMember({
    required this.id,
    required this.name,
    required this.role, this.email,
    this.phone,
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
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String role;
  final String? avatar;
  final DateTime? createdAt;
}

class InventoryItem {

  InventoryItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.image,
    required this.stock,
    required this.price, required this.level, this.unlimitedStock,
    this.soldCount = 0,
    this.hasVariations,
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
}

class InventorySummary {
  InventorySummary({required this.criticalCount, required this.lowThreshold});
  factory InventorySummary.fromJson(Map<String, dynamic> json) => InventorySummary(
        criticalCount: json['criticalCount'] as int,
        lowThreshold: json['lowThreshold'] as int,
      );
  final int criticalCount;
  final int lowThreshold;
}

class InventoryResult {
  InventoryResult({required this.data, required this.pagination, required this.summary});
  final List<InventoryItem> data;
  final Pagination pagination;
  final InventorySummary summary;
}

// --- Dashboard ---

class StatCard {
  StatCard({required this.value, this.deltaPct});
  factory StatCard.fromJson(Map<String, dynamic> json) => StatCard(
        value: json['value'] as num,
        deltaPct: json['deltaPct'] as int?,
      );
  final num value;
  final int? deltaPct;
}

class DashboardCards {

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
  final StatCard todayOrders;
  final StatCard todayRevenue;
  final StatCard pendingOrders;
  final StatCard lowStockItems;
}

class TopProductSummary {

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
        name: (json['name'] as String?) ?? '',
        slug: (json['slug'] as String?) ?? '',
        image: (json['image'] as String?) ?? '',
        soldCount: ((json['soldCount'] ?? json['sold_count']) as int?) ?? 0,
        price: ((json['price'] as num?) ?? 0).toDouble(),
      );
  final String id;
  final String name;
  final String slug;
  final String image;
  final int soldCount;
  final double price;
}

class DashboardData {

  DashboardData({
    required this.cards,
    required this.flaggedOrdersCount,
    required this.recentOrders,
    required this.topProducts,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    // Backend currently returns snake_case keys (today_orders, recent_orders,
    // etc.) — accept both shapes until the backend migrates to camelCase.
    final stats = (json['stats'] as Map<String, dynamic>?) ??
        (json['cards'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final cards = DashboardCards(
      todayOrders: StatCard(
        value: (stats['todayOrders'] ?? stats['today_orders'] ?? 0) as num,
      ),
      todayRevenue: StatCard(
        value: (stats['todayRevenue'] ?? stats['today_revenue'] ?? 0) as num,
      ),
      pendingOrders: StatCard(
        value: (stats['pendingOrders'] ?? stats['pending_orders'] ?? 0) as num,
      ),
      lowStockItems: StatCard(
        value: (stats['lowStockItems'] ??
                stats['low_stock_items'] ??
                stats['low_stock'] ??
                0) as num,
      ),
    );
    final recent = (json['recentOrders'] ?? json['recent_orders'] ?? const [])
        as List;
    final top = (json['topProducts'] ?? json['top_products'] ?? const []) as List;
    return DashboardData(
      cards: cards,
      flaggedOrdersCount: (json['flaggedOrdersCount'] ??
          json['flagged_orders_count'] ??
          0) as int,
      recentOrders: recent
          .map((e) => OrderListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      topProducts: top
          .map((e) => TopProductSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
  final DashboardCards cards;
  final int flaggedOrdersCount;
  final List<OrderListItem> recentOrders;
  final List<TopProductSummary> topProducts;
}

// --- Analytics ---

class AnalyticsStats {

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
  final int orders;
  final double revenue;
  final double avgOrderValue;
  final double returnRate;
}

class RevenuePoint {
  RevenuePoint({required this.date, required this.revenue, required this.orders});
  factory RevenuePoint.fromJson(Map<String, dynamic> json) => RevenuePoint(
        date: json['date'] as String,
        revenue: (json['revenue'] as num).toDouble(),
        orders: json['orders'] as int,
      );
  final String date;
  final double revenue;
  final int orders;
}

class TopProductAnalytics {

  TopProductAnalytics({
    required this.name, required this.unitsSold, required this.revenue, this.productId,
    this.image,
    this.slug,
  });

  factory TopProductAnalytics.fromJson(Map<String, dynamic> json) => TopProductAnalytics(
        productId: json['productId']?.toString(),
        name: json['name'] as String,
        image: json['image'] as String?,
        slug: json['slug'] as String?,
        unitsSold: json['unitsSold'] as int,
        revenue: (json['revenue'] as num).toDouble(),
      );
  final String? productId;
  final String name;
  final String? image;
  final String? slug;
  final int unitsSold;
  final double revenue;
}

class TrafficSource {
  TrafficSource({required this.source, required this.clicks});
  factory TrafficSource.fromJson(Map<String, dynamic> json) =>
      TrafficSource(source: json['source'] as String, clicks: json['clicks'] as int);
  final String source;
  final int clicks;
}

class AnalyticsData {

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
  final String period;
  final DateTime from;
  final DateTime to;
  final AnalyticsStats stats;
  final List<RevenuePoint> revenueChart;
  final List<TopProductAnalytics> topProducts;
  final Map<String, int> statusBreakdown;
  final List<TrafficSource> trafficSources;
}

// =============================================================================
// API client — top-level facade
// =============================================================================

class AkhiyanApi {

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
    categories = CategoriesApi(this);
    brands = BrandsApi(this);
    customers = CustomersApi(this);
    inventory = InventoryApi(this);
    coupons = CouponsApi(this);
    flashSales = FlashSalesApi(this);
    shortlinks = ShortlinksApi(this);
    analytics = AnalyticsApi(this);
    banners = BannersApi(this);
    fraud = FraudApi(this);
    staff = StaffApi(this);
    media = MediaApi(this);
    landingPages = LandingPagesApi(this);
    feeds = FeedsApi(this);
    adminSettings = AdminSettingsApi(this);
  }
  final String baseUrl;
  final TokenStorage _storage;
  final http.Client _http;

  /// Called whenever the access token is invalid (401) — your app
  /// should navigate to the login screen.
  void Function()? onAuthExpired;

  /// Optional tenant slug. When set (typically once at app start from
  /// `Env.tenantSlug` or after an explicit "switch tenant" flow in a future
  /// SaaS build), every outgoing request gains an `X-Tenant-Slug` header so
  /// the backend can scope queries to a single tenant.
  String? tenantSlug;

  late final AuthApi auth;
  late final DashboardApi dashboard;
  late final OrdersApi orders;
  late final ProductsApi products;
  late final CategoriesApi categories;
  late final BrandsApi brands;
  late final CustomersApi customers;
  late final InventoryApi inventory;
  late final CouponsApi coupons;
  late final FlashSalesApi flashSales;
  late final ShortlinksApi shortlinks;
  late final AnalyticsApi analytics;
  late final BannersApi banners;
  late final FraudApi fraud;
  late final StaffApi staff;
  late final MediaApi media;
  late final LandingPagesApi landingPages;
  late final FeedsApi feeds;
  late final AdminSettingsApi adminSettings;

  TokenStorage get storage => _storage;

  Future<bool> get isLoggedIn async => (await _storage.getAccessToken()) != null;

  void close() => _http.close();

  /// Internal: low-level request with auto-refresh on 401. Returns the parsed
  /// `data` field of the `{ data, pagination?, ... }` envelope, or the raw
  /// JSON map if there's no `data` key (rare).
  /// Sibling base for endpoints that live outside the `/m` mobile namespace
  /// (e.g. the public `/api/v1/categories` and `/api/v1/brands` lookups
  /// reused by the product form). Strips a trailing `/m` if present;
  /// otherwise returns [baseUrl] unchanged.
  String get _rootBaseUrl {
    if (baseUrl.endsWith('/m')) return baseUrl.substring(0, baseUrl.length - 2);
    return baseUrl;
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool retried = false,
    bool rootBase = false,
  }) async {
    final base = rootBase ? _rootBaseUrl : baseUrl;
    final uri = Uri.parse('$base$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final access = await _storage.getAccessToken();
    if (access != null) headers['Authorization'] = 'Bearer $access';
    // Forward the tenant slug on every request. Backend ignores it today
    // (single-tenant); when the SaaS migration lands the header becomes the
    // tenant-resolution key. Setting it now means zero Flutter changes are
    // needed at switchover time.
    if (tenantSlug != null && tenantSlug!.isNotEmpty) {
      headers['X-Tenant-Slug'] = tenantSlug!;
    }

    // Hard ceiling per request. Without this the http package waits
    // indefinitely on a stalled socket (Coolify cold-starts, dropped
    // connections, etc.) and the UI shows a "Loading…" overlay that
    // never dismisses. 30s is generous for an admin tool — anything
    // longer is genuinely broken and the user is better off seeing an
    // error and being able to retry.
    const httpTimeout = Duration(seconds: 30);

    // Per-request timing — prints `[api] METHOD path STATUS NNNms` so
    // the user can see in the console exactly which calls are slow.
    // Flag for "is this Flutter or backend?": anything >200ms here is
    // network/backend latency, not Dart code.
    final stopwatch = Stopwatch()..start();

    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await _http.get(uri, headers: headers).timeout(httpTimeout);
        case 'POST':
          res = await _http
              .post(uri, headers: headers, body: body == null ? null : jsonEncode(body))
              .timeout(httpTimeout);
        case 'PATCH':
          res = await _http
              .patch(uri, headers: headers, body: body == null ? null : jsonEncode(body))
              .timeout(httpTimeout);
        case 'PUT':
          res = await _http
              .put(uri, headers: headers, body: body == null ? null : jsonEncode(body))
              .timeout(httpTimeout);
        case 'DELETE':
          res = await _http.delete(uri, headers: headers).timeout(httpTimeout);
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
    } on TimeoutException {
      stopwatch.stop();
      if (kDebugMode) {
        // ignore: avoid_print
        print('[api] $method $path TIMEOUT after ${stopwatch.elapsedMilliseconds}ms');
      }
      throw NetworkException('Request timed out');
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } catch (e) {
      throw NetworkException(e.toString());
    }
    stopwatch.stop();
    if (kDebugMode) {
      // ignore: avoid_print
      print('[api] $method $path ${res.statusCode} ${stopwatch.elapsedMilliseconds}ms');
    }

    // No refresh token in this backend — on 401, clear tokens and notify.
    // The router redirect handles navigation to /login.
    if (res.statusCode == 401 && !retried && path != '/auth/login') {
      await _storage.clear();
      onAuthExpired?.call();
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
        // Pass the whole decoded body so callers can render Zod-style
        // nested errors verbatim when the flattened `details` doesn't
        // capture nested array indices like `items.0.productId`.
        json,
      );
    }

    return json;
  }

}

// =============================================================================
// Auth
// =============================================================================

class AuthApi {
  AuthApi(this._api);
  final AkhiyanApi _api;

  Future<AdminUser> login(String email, String password) async {
    final res = await _api.request('POST', '/auth/login', body: {
      'email': email,
      'password': password,
    });
    final result = LoginResult.fromJson(res as Map<String, dynamic>);
    await _api._storage.save(accessToken: result.accessToken);
    return result.user;
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
  DashboardApi(this._api);
  final AkhiyanApi _api;

  /// Fetches dashboard data, optionally scoped to a date range.
  ///
  /// [from] / [to] are sent as ISO 8601 query params in anticipation of
  /// backend support — the current backend may ignore them, which is fine.
  /// Once the backend honors the filter, the dashboard date-range pill will
  /// drive these values without further client changes.
  Future<DashboardData> fetch({DateTime? from, DateTime? to}) async {
    final res = await _api.request('GET', '/dashboard', query: {
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    });
    return DashboardData.fromJson(res['data'] as Map<String, dynamic>);
  }
}

// =============================================================================
// Orders
// =============================================================================

class OrdersApi {
  OrdersApi(this._api);
  final AkhiyanApi _api;

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
      if (flagged ?? false) 'flagged': 'true',
      'page': '$page',
      'pageSize': '$pageSize',
    });
    return PaginatedResponse<OrderListItem>(
      data: (res['data'] as List).map((e) => OrderListItem.fromJson(e as Map<String, dynamic>)).toList(),
      pagination: _paginationFrom(res as Map<String, dynamic>),
    );
  }

  Future<Order> detail(String id) async {
    final res = await _api.request('GET', '/orders/$id');
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Allowed order statuses for the filter chips on the orders list.
  /// Fetched from the backend so adding a new status (e.g. `returned`,
  /// `refunded`) on the server appears in the app without a release.
  ///
  /// **Backend contract** (GET /api/v1/m/orders/statuses):
  /// ```
  /// { "data": [
  ///     { "key": "pending",    "label": "Pending" },
  ///     { "key": "confirmed",  "label": "Confirmed" },
  ///     ...
  /// ] }
  /// ```
  /// Until the route ships, the Flutter side falls back to a built-in
  /// list so the screen keeps working.
  Future<List<OrderStatusOption>> statuses() async {
    final res = await _api.request('GET', '/orders/statuses');
    return (res['data'] as List)
        .map((e) => OrderStatusOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a manual order (admin-entered, e.g. phone-in or in-store
  /// purchase). Backend computes the canonical subtotal/total from the
  /// items + shippingCost - discount; we send those fields too so the
  /// route can validate the client view, but the server numbers win.
  ///
  /// **Backend contract** (POST /api/v1/m/orders, expected wire shape):
  /// ```
  /// {
  ///   "customerName": "...",
  ///   "customerPhone": "...",
  ///   "customerEmail": "...?",
  ///   "customerAddress": "...",
  ///   "city": "...?",
  ///   "zipCode": "...?",
  ///   "items": [
  ///     { "productId": "...", "variantId": "...?",
  ///       "quantity": 1, "price": 410 }
  ///   ],
  ///   "shippingCost": 60,
  ///   "discount": 0,
  ///   "paymentMethod": "cod" | "bkash" | "nagad" | "card",
  ///   "notes": "...?"
  /// }
  /// ```
  /// Response: `{ "data": <Order> }`. Backend should also call
  /// `bumpVersion('orders')` so the storefront and other admin clients
  /// refresh within a second.
  Future<Order> create({
    required String customerName,
    required String customerPhone,
    required String customerAddress, required List<Map<String, dynamic>> items, String? customerEmail,
    String? city,
    String? zipCode,
    double shippingCost = 0,
    double discount = 0,
    String paymentMethod = 'cod',
    String? notes,
  }) async {
    final res = await _api.request('POST', '/orders', body: {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': ?customerEmail,
      'customerAddress': customerAddress,
      'city': ?city,
      'zipCode': ?zipCode,
      'items': items,
      'shippingCost': shippingCost,
      'discount': discount,
      'paymentMethod': paymentMethod,
      'notes': ?notes,
    });
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> updateStatus(String id, {String? status, String? paymentStatus, String? notes}) async {
    final res = await _api.request('PATCH', '/orders/$id', body: {
      'status': ?status,
      'paymentStatus': ?paymentStatus,
      'notes': ?notes,
    });
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> dispatchToCourier(String id, {required String courier, double? weight, String? instructions}) async {
    final res = await _api.request('POST', '/orders/$id/courier', body: {
      'courier': courier,
      'weight': ?weight,
      'instructions': ?instructions,
    });
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> cancel(String id, {String? reason}) async {
    final res = await _api.request('POST', '/orders/$id/cancel', body: {
      'reason': ?reason,
    });
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> flag(String id, {String? reason}) async {
    final res = await _api.request('POST', '/orders/$id/flag', body: {
      'reason': ?reason,
    });
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> clearFlag(String id) async {
    final res = await _api.request('DELETE', '/orders/$id/flag');
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }
}

// =============================================================================
// Products
// =============================================================================

class ProductsApi {
  ProductsApi(this._api);
  final AkhiyanApi _api;

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
    });
    return PaginatedResponse<Product>(
      data: (res['data'] as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList(),
      pagination: _paginationFrom(res as Map<String, dynamic>),
    );
  }

  Future<Product> detail(String id) async {
    final res = await _api.request('GET', '/products/$id');
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Product> create(Map<String, dynamic> input) async {
    final res = await _api.request('POST', '/products', body: input);
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Product> update(String id, Map<String, dynamic> patch) async {
    final res = await _api.request('PATCH', '/products/$id', body: patch);
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _api.request('DELETE', '/products/$id');
  }

  Future<Map<String, dynamic>> setStock(String id, {int? stock, int? delta}) async {
    assert(stock != null || delta != null, 'Provide stock (absolute) or delta (relative)');
    final res = await _api.request('PATCH', '/products/$id/stock', body: {
      'stock': ?stock,
      'delta': ?delta,
    });
    return res['data'] as Map<String, dynamic>;
  }

}

// =============================================================================
// Categories — read-only via the public `/categories` endpoint (sibling of
// the mobile namespace). Backend filters to active items, sorted by sortOrder.
// =============================================================================

class CategoriesApi {
  CategoriesApi(this._api);
  final AkhiyanApi _api;

  Future<List<Category>> list() async {
    final res = await _api.request('GET', '/categories', rootBase: true);
    return (res['data'] as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// =============================================================================
// Brands — read-only, same shape as Categories.
// =============================================================================

class BrandsApi {
  BrandsApi(this._api);
  final AkhiyanApi _api;

  Future<List<Brand>> list() async {
    final res = await _api.request('GET', '/brands', rootBase: true);
    return (res['data'] as List)
        .map((e) => Brand.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// =============================================================================
// Customers
// =============================================================================

class CustomersApi {
  CustomersApi(this._api);
  final AkhiyanApi _api;

  Future<PaginatedResponse<CustomerListItem>> list({String? q, int page = 1, int pageSize = 20}) async {
    final res = await _api.request('GET', '/customers', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      'page': '$page',
      'pageSize': '$pageSize',
    });
    return PaginatedResponse<CustomerListItem>(
      data: (res['data'] as List).map((e) => CustomerListItem.fromJson(e as Map<String, dynamic>)).toList(),
      pagination: _paginationFrom(res as Map<String, dynamic>),
    );
  }

  Future<CustomerDetail> detail(String id) async {
    final res = await _api.request('GET', '/customers/$id');
    return CustomerDetail.fromJson(res['data'] as Map<String, dynamic>);
  }
}

// =============================================================================
// Inventory
// =============================================================================

class InventoryApi {
  InventoryApi(this._api);
  final AkhiyanApi _api;

  Future<InventoryResult> list({String? stockFilter, String? q, int page = 1, int pageSize = 50}) async {
    final res = await _api.request('GET', '/inventory', query: {
      if (stockFilter != null && stockFilter.isNotEmpty) 'stockFilter': stockFilter,
      if (q != null && q.isNotEmpty) 'q': q,
      'page': '$page',
      'pageSize': '$pageSize',
    });
    return InventoryResult(
      data: (res['data'] as List).map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList(),
      pagination: _paginationFrom(res as Map<String, dynamic>),
      summary: InventorySummary.fromJson(res['summary'] as Map<String, dynamic>),
    );
  }

}

// =============================================================================
// Coupons
// =============================================================================

class CouponsApi {
  CouponsApi(this._api);
  final AkhiyanApi _api;

  Future<List<Coupon>> list({bool? active}) async {
    final res = await _api.request('GET', '/coupons', query: {
      if (active != null) 'active': active.toString(),
    });
    return (res['data'] as List).map((e) => Coupon.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Coupon> detail(String id) async {
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

  Future<Coupon> update(String id, Map<String, dynamic> patch) async {
    final res = await _api.request('PATCH', '/coupons/$id', body: patch);
    return Coupon.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _api.request('DELETE', '/coupons/$id');
  }
}

// =============================================================================
// Flash Sales
// =============================================================================

class FlashSalesApi {
  FlashSalesApi(this._api);
  final AkhiyanApi _api;

  Future<List<FlashSale>> list() async {
    final res = await _api.request('GET', '/flash-sales');
    return (res['data'] as List).map((e) => FlashSale.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> detail(String id) async {
    final res = await _api.request('GET', '/flash-sales/$id');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create({
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    bool isActive = true,
    List<String>? productIds,
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

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> patch) async {
    final res = await _api.request('PATCH', '/flash-sales/$id', body: patch);
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _api.request('DELETE', '/flash-sales/$id');
  }
}

// =============================================================================
// Shortlinks
// =============================================================================

class ShortlinksApi {
  ShortlinksApi(this._api);
  final AkhiyanApi _api;

  Future<List<Shortlink>> list() async {
    final res = await _api.request('GET', '/shortlinks');
    return (res['data'] as List).map((e) => Shortlink.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> detail(String id) async {
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

  Future<Shortlink> update(String id, {String? targetUrl, bool? isActive}) async {
    final res = await _api.request('PATCH', '/shortlinks/$id', body: {
      'targetUrl': ?targetUrl,
      'isActive': ?isActive,
    });
    return Shortlink.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _api.request('DELETE', '/shortlinks/$id');
  }
}

// =============================================================================
// Analytics
// =============================================================================

class AnalyticsApi {
  AnalyticsApi(this._api);
  final AkhiyanApi _api;

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
  BannersApi(this._api);
  final AkhiyanApi _api;

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

  Future<AdminBanner> update(String id, Map<String, dynamic> patch) async {
    final res = await _api.request('PATCH', '/marketing/banners/$id', body: patch);
    return AdminBanner.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _api.request('DELETE', '/marketing/banners/$id');
  }
}

// =============================================================================
// Fraud
// =============================================================================

class FraudApi {
  FraudApi(this._api);
  final AkhiyanApi _api;

  Future<PaginatedResponse<FlaggedOrder>> flaggedOrders({int page = 1, int pageSize = 20}) async {
    final res = await _api.request('GET', '/fraud/orders', query: {
      'page': '$page',
      'pageSize': '$pageSize',
    });
    return PaginatedResponse<FlaggedOrder>(
      data: (res['data'] as List).map((e) => FlaggedOrder.fromJson(e as Map<String, dynamic>)).toList(),
      pagination: _paginationFrom(res as Map<String, dynamic>),
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
  StaffApi(this._api);
  final AkhiyanApi _api;

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

  Future<StaffMember> update(String id, {String? name, String? phone, String? role}) async {
    final res = await _api.request('PATCH', '/staff/$id', body: {
      'name': ?name,
      'phone': ?phone,
      'role': ?role,
    });
    return StaffMember.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _api.request('DELETE', '/staff/$id');
  }
}

// =============================================================================
// Media (image uploads)
// =============================================================================

/// Image / file upload helper. POSTs `multipart/form-data` to
/// `/uploads` and returns the hosted URL the backend assigned. Used by the
/// product form (and any other screen that needs to attach media).
///
/// **Backend contract** the Flutter app expects:
///
///   POST /api/v1/m/uploads
///   Content-Type: multipart/form-data
///   field name: "file"
///
///   Response 200:
///     { "data": { "url": "https://cdn.example.com/xyz.jpg" } }
///
/// If the route doesn't exist yet, the app surfaces a friendly error and
/// the form keeps working — users just can't add new images. Once the
/// backend ships the endpoint, no app changes are needed.
class MediaApi {
  MediaApi(this._api);
  final AkhiyanApi _api;

  /// Upload bytes from disk and return the hosted URL. Content-Type is
  /// inferred from the filename extension server-side — Flutter's `http`
  /// package doesn't ship `MediaType` parsing without `http_parser`, and
  /// the backend's existing upload route already sniffs the MIME from the
  /// uploaded extension.
  Future<String> upload({
    required List<int> bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('${_api.baseUrl}/uploads');
    final req = http.MultipartRequest('POST', uri);

    final access = await _api._storage.getAccessToken();
    if (access != null) req.headers['Authorization'] = 'Bearer $access';
    if (_api.tenantSlug != null && _api.tenantSlug!.isNotEmpty) {
      req.headers['X-Tenant-Slug'] = _api.tenantSlug!;
    }
    req.headers['Accept'] = 'application/json';

    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 401) {
      await _api._storage.clear();
      _api.onAuthExpired?.call();
      throw ApiException(401, 'Session expired');
    }

    var json = const <String, dynamic>{};
    if (body.isNotEmpty) {
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        throw ApiException(streamed.statusCode, 'Server returned invalid JSON');
      }
    }

    if (streamed.statusCode >= 400) {
      final message = (json['message'] as String?) ??
          (json['error'] as String?) ??
          'Upload failed';
      throw ApiException(streamed.statusCode, message);
    }

    final data = json['data'] as Map<String, dynamic>?;
    final url = data?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw ApiException(500, 'Server did not return a URL');
    }
    return url;
  }
}

// =============================================================================
// Landing Pages — admin-managed marketing pages.
// =============================================================================

/// One landing page row. Mobile only edits the "core" fields directly
/// (title/slug/active/hero block/primaryColor); the JSON arrays
/// (features, testimonials, faq, sections, problemPoints, howItWorks)
/// are passed through verbatim from the server so saves don't lose
/// rich content the web admin authored.
class LandingPage {
  LandingPage({
    required this.id,
    required this.slug,
    required this.title,
    this.isActive = true,
    this.heroHeadline,
    this.heroSubheadline,
    this.heroImage,
    this.heroCta,
    this.heroBadge,
    this.heroTrustText,
    this.primaryColor,
    this.metaTitle,
    this.metaDescription,
    this.createdAt,
    this.raw = const {},
  });

  factory LandingPage.fromJson(Map<String, dynamic> json) => LandingPage(
        id: (json['id'] ?? '').toString(),
        slug: (json['slug'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        isActive: (json['isActive'] ?? json['is_active'] ?? true) as bool,
        heroHeadline:
            (json['heroHeadline'] ?? json['hero_headline']) as String?,
        heroSubheadline:
            (json['heroSubheadline'] ?? json['hero_subheadline']) as String?,
        heroImage: (json['heroImage'] ?? json['hero_image']) as String?,
        heroCta: (json['heroCta'] ?? json['hero_cta']) as String?,
        heroBadge: (json['heroBadge'] ?? json['hero_badge']) as String?,
        heroTrustText:
            (json['heroTrustText'] ?? json['hero_trust_text']) as String?,
        primaryColor:
            (json['primaryColor'] ?? json['primary_color']) as String?,
        metaTitle: (json['metaTitle'] ?? json['meta_title']) as String?,
        metaDescription:
            (json['metaDescription'] ?? json['meta_description']) as String?,
        createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
        raw: json,
      );

  final String id;
  final String slug;
  final String title;
  final bool isActive;
  final String? heroHeadline;
  final String? heroSubheadline;
  final String? heroImage;
  final String? heroCta;
  final String? heroBadge;
  final String? heroTrustText;
  final String? primaryColor;
  final String? metaTitle;
  final String? metaDescription;
  final DateTime? createdAt;

  /// Full server payload — kept so PUT requests can preserve fields the
  /// mobile editor doesn't surface (features/testimonials/faq/sections).
  /// The save flow merges `raw` with the edited core fields before sending.
  final Map<String, dynamic> raw;
}

class LandingPagesApi {
  LandingPagesApi(this._api);
  final AkhiyanApi _api;

  /// `GET /landing-pages` — returns a flat array (no envelope) per the
  /// admin handler. Sorted desc by createdAt server-side.
  Future<List<LandingPage>> list() async {
    final res = await _api.request('GET', '/landing-pages');
    final list = (res is List ? res : (res['data'] as List? ?? []));
    return list
        .map((e) => LandingPage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LandingPage> detail(String id) async {
    final res = await _api.request('GET', '/landing-pages/$id');
    final data = res is Map<String, dynamic>
        ? (res['data'] is Map ? res['data'] as Map<String, dynamic> : res)
        : <String, dynamic>{};
    return LandingPage.fromJson(data);
  }

  /// Update the core fields. Other fields (features, testimonials, etc.)
  /// are preserved from [base.raw] so a mobile save doesn't wipe rich
  /// content the web admin authored.
  Future<LandingPage> update(
    String id, {
    required LandingPage base,
    String? title,
    String? slug,
    bool? isActive,
    String? heroHeadline,
    String? heroSubheadline,
    String? heroImage,
    String? heroCta,
    String? heroBadge,
    String? heroTrustText,
    String? primaryColor,
    String? metaTitle,
    String? metaDescription,
  }) async {
    final body = _buildLandingPagePayload(
      base: base,
      title: title,
      slug: slug,
      isActive: isActive,
      heroHeadline: heroHeadline,
      heroSubheadline: heroSubheadline,
      heroImage: heroImage,
      heroCta: heroCta,
      heroBadge: heroBadge,
      heroTrustText: heroTrustText,
      primaryColor: primaryColor,
      metaTitle: metaTitle,
      metaDescription: metaDescription,
    );
    final res = await _api.request('PUT', '/landing-pages/$id', body: body);
    final data = res is Map<String, dynamic>
        ? (res['data'] is Map ? res['data'] as Map<String, dynamic> : res)
        : <String, dynamic>{};
    return LandingPage.fromJson(data);
  }

  Future<LandingPage> create({
    required String title,
    String? slug,
    bool isActive = true,
    String? heroHeadline,
    String? heroSubheadline,
    String? heroImage,
    String? heroCta,
    String? primaryColor,
  }) async {
    final res = await _api.request('POST', '/landing-pages', body: {
      'title': title,
      if (slug != null && slug.isNotEmpty) 'slug': slug,
      'is_active': isActive,
      if (heroHeadline != null) 'hero_headline': heroHeadline,
      if (heroSubheadline != null) 'hero_subheadline': heroSubheadline,
      if (heroImage != null) 'hero_image': heroImage,
      if (heroCta != null) 'hero_cta': heroCta,
      if (primaryColor != null) 'primary_color': primaryColor,
    });
    final data = res is Map<String, dynamic>
        ? (res['data'] is Map ? res['data'] as Map<String, dynamic> : res)
        : <String, dynamic>{};
    return LandingPage.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _api.request('DELETE', '/landing-pages/$id');
  }
}

/// Build the snake_case PUT payload. Walks `base.raw` so anything the
/// mobile editor doesn't expose (features array, testimonials array, etc.)
/// rides through unchanged. Returns a NEW map — never mutates `base.raw`.
Map<String, dynamic> _buildLandingPagePayload({
  required LandingPage base,
  String? title,
  String? slug,
  bool? isActive,
  String? heroHeadline,
  String? heroSubheadline,
  String? heroImage,
  String? heroCta,
  String? heroBadge,
  String? heroTrustText,
  String? primaryColor,
  String? metaTitle,
  String? metaDescription,
}) {
  // Snake-case copy of the original payload as the starting point. We
  // re-key from camelCase to snake_case because the schema validation on
  // the server expects snake_case keys (it accepts both, but snake is the
  // canonical wire format).
  final out = <String, dynamic>{};

  void copy(String camel, String snake) {
    if (base.raw.containsKey(snake)) {
      out[snake] = base.raw[snake];
    } else if (base.raw.containsKey(camel)) {
      out[snake] = base.raw[camel];
    }
  }

  // Pass-through rich JSON fields verbatim.
  for (final entry in const [
    ('problemTitle', 'problem_title'),
    ('problemPoints', 'problem_points'),
    ('productsTitle', 'products_title'),
    ('productsSub', 'products_subtitle'),
    ('featuresTitle', 'features_title'),
    ('featuresImage', 'features_image'),
    ('features', 'features'),
    ('testimonialsTitle', 'testimonials_title'),
    ('testimonialsMode', 'testimonials_mode'),
    ('testimonials', 'testimonials'),
    ('howItWorksTitle', 'how_it_works_title'),
    ('howItWorksSub', 'how_it_works_subtitle'),
    ('howItWorks', 'how_it_works'),
    ('faqTitle', 'faq_title'),
    ('faq', 'faq'),
    ('products', 'products'),
    ('checkoutTitle', 'checkout_title'),
    ('checkoutSubtitle', 'checkout_subtitle'),
    ('checkoutBtnText', 'checkout_btn_text'),
    ('customShipping', 'custom_shipping'),
    ('shippingCost', 'shipping_cost'),
    ('showEmail', 'show_email'),
    ('showCity', 'show_city'),
    ('guaranteeText', 'guarantee_text'),
    ('successMessage', 'success_message'),
    ('whatsapp', 'whatsapp'),
    ('contactMode', 'contact_mode'),
    ('sectionVisibility', 'section_visibility'),
    ('heroVideoAutoplay', 'hero_video_autoplay'),
  ]) {
    copy(entry.$1, entry.$2);
  }

  // Core editable fields — overlay edits on top of the passthrough copy.
  out['title'] = title ?? base.title;
  out['slug'] = slug ?? base.slug;
  out['is_active'] = isActive ?? base.isActive;
  out['hero_headline'] = heroHeadline ?? base.heroHeadline;
  out['hero_subheadline'] = heroSubheadline ?? base.heroSubheadline;
  out['hero_image'] = heroImage ?? base.heroImage;
  out['hero_cta'] = heroCta ?? base.heroCta;
  out['hero_badge'] = heroBadge ?? base.heroBadge;
  out['hero_trust_text'] = heroTrustText ?? base.heroTrustText;
  out['primary_color'] = primaryColor ?? base.primaryColor ?? '#0f5931';
  out['meta_title'] = metaTitle ?? base.metaTitle;
  out['meta_description'] = metaDescription ?? base.metaDescription;
  return out;
}

// =============================================================================
// Product Feeds — shared defaults + read-only stats.
// =============================================================================

class FeedDefaults {
  const FeedDefaults({
    this.brand,
    this.condition,
    this.googleProductCategory,
    this.siteUrl,
  });

  factory FeedDefaults.fromJson(Map<String, dynamic> json) => FeedDefaults(
        brand: json['brand'] as String?,
        condition: json['condition'] as String?,
        googleProductCategory:
            (json['google_product_category'] ?? json['googleProductCategory'])
                as String?,
        siteUrl: (json['site_url'] ?? json['siteUrl']) as String?,
      );

  final String? brand;
  final String? condition;
  final String? googleProductCategory;
  final String? siteUrl;
}

class FeedStats {
  const FeedStats({
    this.rowsInFeed = 0,
    this.activeProducts = 0,
    this.totalProducts = 0,
    this.activeFlashSales = 0,
    this.inStock = 0,
    this.outOfStock = 0,
    this.onSale = 0,
  });

  factory FeedStats.fromJson(Map<String, dynamic> json) => FeedStats(
        rowsInFeed: (json['rowsInFeed'] ?? 0) as int,
        activeProducts: (json['activeProducts'] ?? 0) as int,
        totalProducts: (json['totalProducts'] ?? 0) as int,
        activeFlashSales: (json['activeFlashSales'] ?? 0) as int,
        inStock: (json['inStock'] ?? 0) as int,
        outOfStock: (json['outOfStock'] ?? 0) as int,
        onSale: (json['onSale'] ?? 0) as int,
      );

  final int rowsInFeed;
  final int activeProducts;
  final int totalProducts;
  final int activeFlashSales;
  final int inStock;
  final int outOfStock;
  final int onSale;
}

class FeedConfig {
  const FeedConfig({required this.defaults, required this.stats});

  factory FeedConfig.fromJson(Map<String, dynamic> json) => FeedConfig(
        defaults:
            FeedDefaults.fromJson((json['defaults'] as Map<String, dynamic>?) ?? {}),
        stats: FeedStats.fromJson((json['stats'] as Map<String, dynamic>?) ?? {}),
      );

  final FeedDefaults defaults;
  final FeedStats stats;
}

class FeedsApi {
  FeedsApi(this._api);
  final AkhiyanApi _api;

  Future<FeedConfig> fetch() async {
    final res = await _api.request('GET', '/feeds');
    final data = res is Map<String, dynamic>
        ? (res['data'] is Map ? res['data'] as Map<String, dynamic> : res)
        : <String, dynamic>{};
    return FeedConfig.fromJson(data);
  }

  /// Returns the new defaults shape after save by re-fetching. The PUT
  /// response body is just `{ message: 'Saved' }` — server doesn't echo
  /// the full payload back, so we round-trip to keep the UI in sync.
  Future<FeedConfig> save({
    String? brand,
    String? condition,
    String? googleProductCategory,
    String? siteUrl,
  }) async {
    await _api.request('PUT', '/feeds', body: {
      if (brand != null) 'brand': brand,
      if (condition != null) 'condition': condition,
      if (googleProductCategory != null)
        'google_product_category': googleProductCategory,
      if (siteUrl != null) 'site_url': siteUrl,
    });
    return fetch();
  }
}

// =============================================================================
// Admin settings — unified key/value store backing every settings section
// in the dashboard.
// =============================================================================

/// Sentinel the backend uses to mask secrets (SMTP password, Pathao secret,
/// Steadfast keys, FB CAPI token, …) on GET. The Flutter editor renders any
/// field whose value matches this with a "Saved (hidden)" placeholder, and
/// skips it on save so we never overwrite the real secret with the mask.
const kSecretMask = '••••••••';

class AdminSettingsApi {
  AdminSettingsApi(this._api);
  final AkhiyanApi _api;

  /// Returns every site_setting row as a flat key→value map. Sensitive
  /// keys come back as [kSecretMask] (write-only secrets).
  Future<Map<String, String?>> fetch() async {
    final res = await _api.request('GET', '/admin/settings');
    if (res is! Map<String, dynamic>) return const {};
    return res.map((k, v) => MapEntry(k, v?.toString()));
  }

  /// Save a partial map of changes. Keys not in the map are left untouched
  /// on the server. Values equal to [kSecretMask] are stripped before
  /// sending — the server also ignores them as a second line of defence,
  /// but we filter client-side too to keep the request small.
  Future<void> save(Map<String, String?> changes) async {
    final body = <String, String?>{
      for (final e in changes.entries)
        if (e.value != kSecretMask) e.key: e.value,
    };
    if (body.isEmpty) return;
    await _api.request('PUT', '/admin/settings', body: body);
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
