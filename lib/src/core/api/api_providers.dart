import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/akhiyan_api.dart';
import '../../../config/env.dart';
import '../../features/auth/application/auth_controller.dart';
import 'api_config.dart';
import 'secure_token_storage.dart';

/// Singleton-ish [AkhiyanApi] for the whole app. Created lazily on first
/// access, base URL chosen by [ApiConfig], tokens persisted via
/// [SecureTokenStorage].
///
/// Listen to this provider in screens that need to call the backend:
/// ```dart
/// final api = ref.read(akhiyanApiProvider);
/// final data = await api.dashboard.fetch();
/// ```
final akhiyanApiProvider = Provider<AkhiyanApi>((ref) {
  late final AkhiyanApi api;
  api = AkhiyanApi(
    baseUrl: ApiConfig.baseUrl,
    storage: SecureTokenStorage(),
    onAuthExpired: () {
      // Tokens already cleared by AkhiyanApi.request on 401. Invalidate the
      // auth controller so its state goes null; the GoRouter redirect then
      // kicks the user to /login.
      ref.invalidate(authControllerProvider);
    },
  );
  // Forward-compat for the SaaS migration: pass through Env.tenantSlug if
  // set at build time. Empty by default, which the backend ignores today.
  if (Env.tenantSlug.isNotEmpty) api.tenantSlug = Env.tenantSlug;
  ref.onDispose(api.close);
  return api;
});

/// Async dashboard data scoped to a [DateTimeRange]. Keyed by the range so
/// switching presets on the dashboard pill re-fetches transparently. Refresh
/// the *current* range via `ref.invalidate(dashboardDataProvider(range))`.
final dashboardDataProvider =
    FutureProvider.autoDispose.family<DashboardData, DateTimeRange>(
  (ref, range) => ref.watch(akhiyanApiProvider).dashboard.fetch(
        from: range.start,
        to: range.end,
      ),
);

/// Default page size for paginated list screens. Small enough to feel snappy
/// on slow networks; users navigate via numbered pagination.
const int kListPageSize = 20;

/// Generic single-page list state. Holds only the items for the currently
/// visible page (no accumulation across pages) plus enough metadata for the
/// numbered pagination bar to render.
@immutable
class PagedListState<T> {
  final List<T> items;
  final int currentPage; // 1-based; 0 means "nothing loaded yet"
  final int totalPages;
  final int total;
  final bool loading;
  final Object? error;

  const PagedListState({
    this.items = const [],
    this.currentPage = 0,
    this.totalPages = 0,
    this.total = 0,
    this.loading = false,
    this.error,
  });

  PagedListState<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? totalPages,
    int? total,
    bool? loading,
    Object? error,
    bool clearError = false,
  }) {
    return PagedListState<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Base notifier that owns page navigation, loading, and error bookkeeping.
/// Subclasses override [fetchPage] to call the right
/// `AkhiyanApi.<x>.list(page, pageSize)`.
///
/// The visible items are replaced on every page change — there is no
/// accumulation. The screen renders a numbered pagination bar at the bottom
/// and calls [goToPage] when the user taps a number / arrow.
abstract class SinglePageNotifier<T> extends Notifier<PagedListState<T>> {
  bool _disposed = false;

  Future<PaginatedResponse<T>> fetchPage(int page, int pageSize);

  @override
  PagedListState<T> build() {
    ref.onDispose(() => _disposed = true);
    // Kick off page 1 on first watch (matches the old behaviour where the
    // screen got data on first render).
    Future.microtask(() => goToPage(1));
    return const PagedListState(loading: true);
  }

  /// Fetch [page] (1-based) and replace the visible items. Surfaces errors via
  /// [PagedListState.error]; existing items are preserved on failure so the UI
  /// can keep rendering the previous page while showing an error toast/inline.
  Future<void> goToPage(int page) async {
    if (page < 1) page = 1;
    final prev = state;
    state = prev.copyWith(loading: true, clearError: true);
    try {
      final res = await fetchPage(page, kListPageSize);
      if (_disposed) return;
      state = PagedListState<T>(
        items: res.data,
        currentPage: res.pagination.page,
        totalPages: res.pagination.totalPages,
        total: res.pagination.total,
        loading: false,
      );
    } catch (e) {
      if (_disposed) return;
      // Keep previously-loaded items so the UI doesn't blank out on a flaky
      // navigation; surface the error so the screen can decide what to show.
      state = prev.copyWith(loading: false, error: e);
    }
  }

  /// Reload the current page. Used by pull-to-refresh.
  Future<void> refresh() => goToPage(state.currentPage <= 0 ? 1 : state.currentPage);

  Future<void> nextPage() {
    final s = state;
    if (s.currentPage >= s.totalPages) return Future.value();
    return goToPage(s.currentPage + 1);
  }

  Future<void> prevPage() {
    final s = state;
    if (s.currentPage <= 1) return Future.value();
    return goToPage(s.currentPage - 1);
  }
}

class _ProductsPagedNotifier extends SinglePageNotifier<Product> {
  @override
  Future<PaginatedResponse<Product>> fetchPage(int page, int pageSize) =>
      ref.read(akhiyanApiProvider).products.list(page: page, pageSize: pageSize);
}

class _OrdersPagedNotifier extends SinglePageNotifier<OrderListItem> {
  @override
  Future<PaginatedResponse<OrderListItem>> fetchPage(int page, int pageSize) =>
      ref.read(akhiyanApiProvider).orders.list(page: page, pageSize: pageSize);
}

class _CustomersPagedNotifier extends SinglePageNotifier<CustomerListItem> {
  @override
  Future<PaginatedResponse<CustomerListItem>> fetchPage(
          int page, int pageSize) =>
      ref
          .read(akhiyanApiProvider)
          .customers
          .list(page: page, pageSize: pageSize);
}

/// Products list — single page at a time. The screen renders a numbered
/// pagination bar and calls `goToPage(n)` when the user taps a page.
final productsListProvider = NotifierProvider.autoDispose<
    SinglePageNotifier<Product>, PagedListState<Product>>(
  _ProductsPagedNotifier.new,
);

/// Orders list — single page at a time.
final ordersListProvider = NotifierProvider.autoDispose<
    SinglePageNotifier<OrderListItem>, PagedListState<OrderListItem>>(
  _OrdersPagedNotifier.new,
);

/// Customers list — single page at a time.
final customersListProvider = NotifierProvider.autoDispose<
    SinglePageNotifier<CustomerListItem>, PagedListState<CustomerListItem>>(
  _CustomersPagedNotifier.new,
);

/// Inventory list. Invalidate to refresh.
final inventoryListProvider =
    FutureProvider.autoDispose<InventoryResult>(
  (ref) => ref.watch(akhiyanApiProvider).inventory.list(pageSize: 100),
);

/// Analytics for default 30d period. Invalidate to refresh.
final analyticsDataProvider = FutureProvider.autoDispose<AnalyticsData>(
  (ref) => ref.watch(akhiyanApiProvider).analytics.fetch(period: '30d'),
);
