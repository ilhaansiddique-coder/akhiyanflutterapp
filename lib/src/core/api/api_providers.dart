import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/akhiyan_api.dart';
import '../../../config/env.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
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

/// Logged-in user profile fetched from `/auth/me`. Returns the full
/// [AdminUser] (name, email, phone, role, avatar) — richer than the
/// short `AuthSession` cached at login time.
final currentUserProvider = FutureProvider<AdminUser>(
  (ref) => ref.watch(akhiyanApiProvider).auth.me(),
);

/// All active product categories. Cached for the app's lifetime — categories
/// rarely change, and the product form needs them on every open. Invalidate
/// after creating a new category to force a refetch.
final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(akhiyanApiProvider).categories.list(),
);

/// All active brands. Same caching strategy as [categoriesProvider].
final brandsProvider = FutureProvider<List<Brand>>(
  (ref) => ref.watch(akhiyanApiProvider).brands.list(),
);

/// Single order with full details (items, courier, payment, customer
/// address). Keyed by order id so two open detail screens don't share state.
/// Auto-disposed: detail data is only relevant while the screen is mounted —
/// freeing it on pop keeps the cache from bloating across navigation.
final orderDetailProvider =
    FutureProvider.family.autoDispose<Order, String>(
  (ref, orderId) => ref.watch(akhiyanApiProvider).orders.detail(orderId),
);

/// Full product detail (with variants) by id. Cached for the app lifetime
/// — admins commonly pick the same product family for multiple line items
/// while building an order, and re-fetching `/products/:id` on every variant
/// sheet open burns 200–800ms per tap on Coolify+sslip.io. Invalidated by
/// [syncInvalidationProvider] when the backend emits a `products` bump.
final productDetailProvider =
    FutureProvider.family<Product, String>(
  (ref, id) => ref.watch(akhiyanApiProvider).products.detail(id),
);

/// Async dashboard data scoped to a [DateTimeRange]. Keyed by the range so
/// switching presets on the dashboard pill re-fetches transparently.
///
/// Auto-disposed. Without it, every `bumpVersion('orders'|'products')`
/// arriving over SSE would force a full dashboard refetch (stats + recent
/// orders + top products + revenue chart) even when the user is on a
/// different screen — wasted bandwidth and battery. With autoDispose the
/// provider tears down when no screen watches it, so off-screen bumps
/// become no-ops; the dashboard fetches fresh on next entry.
final dashboardDataProvider =
    FutureProvider.family.autoDispose<DashboardData, DateTimeRange>(
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
  final bool refreshing;
  final Object? error;

  const PagedListState({
    this.items = const [],
    this.currentPage = 0,
    this.totalPages = 0,
    this.total = 0,
    this.loading = false,
    this.refreshing = false,
    this.error,
  });

  PagedListState<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? totalPages,
    int? total,
    bool? loading,
    bool? refreshing,
    Object? error,
    bool clearError = false,
  }) {
    return PagedListState<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
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
///
/// Caching: every page that has been fetched is stored in [_pageCache] so
/// that flipping back to a previously-viewed page is instant (no spinner,
/// no network). The cache is cleared on [refresh]. After each successful
/// fetch we also fire-and-forget a prefetch for `page + 1` to make Next
/// feel instant.
abstract class SinglePageNotifier<T> extends Notifier<PagedListState<T>> {
  bool _disposed = false;

  /// Per-page result cache. Lives outside the immutable state so the state
  /// class stays small and we don't pay copy costs every navigation.
  final Map<int, List<T>> _pageCache = {};

  /// Pages currently being prefetched in the background. Prevents duplicate
  /// prefetch requests if the user navigates again before the prefetch
  /// resolves.
  final Set<int> _prefetching = {};

  Future<PaginatedResponse<T>> fetchPage(int page, int pageSize);

  @override
  PagedListState<T> build() {
    ref.onDispose(() => _disposed = true);
    // Kick off page 1 on first watch (matches the old behaviour where the
    // screen got data on first render).
    Future.microtask(() => goToPage(1));
    // Explicit <T>: a `const PagedListState(loading: true)` would be
    // inferred as `PagedListState<Never>`, which makes `copyWith` reject
    // the typed item lists we set on first fetch.
    return PagedListState<T>(loading: true);
  }

  /// Fetch [page] (1-based) and replace the visible items. Surfaces errors via
  /// [PagedListState.error]; existing items are preserved on failure so the UI
  /// can keep rendering the previous page while showing an error toast/inline.
  ///
  /// Cache behaviour:
  ///   - If [page] is in [_pageCache]: swap items immediately (zero spinner)
  ///     and skip the network call entirely. This is the hot path that makes
  ///     flipping back and forth instant.
  ///   - Otherwise: keep the previous items visible, set `loading = true`,
  ///     and fetch.
  ///
  /// On success we also kick off a background prefetch for `page + 1`.
  Future<void> goToPage(int page) async {
    if (page < 1) page = 1;
    final prev = state;

    // Cached page → instant swap, no network, no spinner.
    final cached = _pageCache[page];
    if (cached != null) {
      state = prev.copyWith(
        items: cached,
        currentPage: page,
        loading: false,
        refreshing: false,
        clearError: true,
      );
      _maybePrefetch(page + 1);
      return;
    }

    // Not cached → keep previous items visible, show loading.
    state = prev.copyWith(loading: true, clearError: true);
    try {
      final res = await fetchPage(page, kListPageSize);
      if (_disposed) return;
      _pageCache[res.pagination.page] = res.data;
      state = PagedListState<T>(
        items: res.data,
        currentPage: res.pagination.page,
        totalPages: res.pagination.totalPages,
        total: res.pagination.total,
        loading: false,
        refreshing: false,
      );
      _maybePrefetch(res.pagination.page + 1);
    } catch (e) {
      if (_disposed) return;
      // Keep previously-loaded items so the UI doesn't blank out on a flaky
      // navigation; surface the error so the screen can decide what to show.
      state = prev.copyWith(loading: false, refreshing: false, error: e);
    }
  }

  /// Fire-and-forget prefetch for [page]. Skips if out of range, already
  /// cached, or already in flight. Errors are swallowed — prefetch failures
  /// must never surface to the user.
  void _maybePrefetch(int page) {
    final s = state;
    if (page < 1) return;
    if (s.totalPages > 0 && page > s.totalPages) return;
    if (_pageCache.containsKey(page)) return;
    if (_prefetching.contains(page)) return;
    _prefetching.add(page);
    // Intentionally not awaited.
    () async {
      try {
        final res = await fetchPage(page, kListPageSize);
        if (_disposed) return;
        _pageCache[res.pagination.page] = res.data;
      } catch (_) {
        // Silent — user didn't request this page.
      } finally {
        _prefetching.remove(page);
      }
    }();
  }

  /// Reload the current page from the network without blanking out the UI.
  ///
  /// Used by SSE-driven sync invalidation and pull-to-refresh. Sets
  /// `refreshing: true` (a quiet flag) instead of `loading: true`, so
  /// screens that key their "Loading page X..." overlay off `loading`
  /// don't flash a blocking spinner just because the backend bumped a
  /// version. The existing items stay rendered until the new ones swap
  /// in atomically on success — feels instant.
  Future<void> refresh() async {
    _pageCache.clear();
    _prefetching.clear();
    final page = state.currentPage <= 0 ? 1 : state.currentPage;
    final prev = state;
    state = prev.copyWith(refreshing: true, clearError: true);
    try {
      final res = await fetchPage(page, kListPageSize);
      if (_disposed) return;
      _pageCache[res.pagination.page] = res.data;
      state = PagedListState<T>(
        items: res.data,
        currentPage: res.pagination.page,
        totalPages: res.pagination.totalPages,
        total: res.pagination.total,
      );
      _maybePrefetch(res.pagination.page + 1);
    } catch (e) {
      if (_disposed) return;
      // Keep the previous items visible — the user shouldn't lose their
      // list because a background bump fetch failed. Surface the error
      // so the screen can opt to render an inline banner if it wants.
      state = prev.copyWith(refreshing: false, error: e);
    }
  }

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

class _InventoryPagedNotifier extends SinglePageNotifier<InventoryItem> {
  @override
  Future<PaginatedResponse<InventoryItem>> fetchPage(
      int page, int pageSize) async {
    final res = await ref
        .read(akhiyanApiProvider)
        .products
        .list(page: page, pageSize: pageSize);
    final items = res.data.map((p) {
      final String level;
      if (p.unlimitedStock == true) {
        level = 'unlimited';
      } else if (p.stock <= 0) {
        level = 'critical';
      } else if (p.stock <= 5) {
        level = 'low';
      } else {
        level = 'ok';
      }
      return InventoryItem(
        id: p.id,
        name: p.name,
        slug: p.slug,
        image: p.image,
        stock: p.stock,
        unlimitedStock: p.unlimitedStock,
        soldCount: p.soldCount,
        price: p.price,
        hasVariations: p.hasVariations,
        level: level,
        variants: p.variants ?? const [],
      );
    }).toList();
    return PaginatedResponse<InventoryItem>(
      data: items,
      pagination: res.pagination,
    );
  }
}

/// Products list — single page at a time. The screen renders a numbered
/// pagination bar and calls `goToPage(n)` when the user taps a page.
final productsListProvider = NotifierProvider<
    SinglePageNotifier<Product>, PagedListState<Product>>(
  _ProductsPagedNotifier.new,
);

/// Orders list — single page at a time.
final ordersListProvider = NotifierProvider<
    SinglePageNotifier<OrderListItem>, PagedListState<OrderListItem>>(
  _OrdersPagedNotifier.new,
);

/// Customers list — single page at a time.
final customersListProvider = NotifierProvider<
    SinglePageNotifier<CustomerListItem>, PagedListState<CustomerListItem>>(
  _CustomersPagedNotifier.new,
);

/// Inventory list — derived from the products endpoint until the backend
/// implements `/inventory`. Single page at a time, with numbered pagination.
final inventoryListProvider = NotifierProvider<
    SinglePageNotifier<InventoryItem>, PagedListState<InventoryItem>>(
  _InventoryPagedNotifier.new,
);

/// Analytics for default 30d period. Invalidate to refresh.
///
/// Keep-alive (no autoDispose): the analytics screen is data-heavy
/// (~30 daily revenue points + topProducts + statusBreakdown) and users
/// flip away from it constantly. Disposing on every screen exit forced a
/// fresh round trip on every return; the in-memory cost is tiny and
/// freshness is governed by `bumpVersion("orders")` / explicit pull-to-
/// refresh anyway.
final analyticsDataProvider = FutureProvider<AnalyticsData>(
  (ref) => ref.watch(akhiyanApiProvider).analytics.fetch(period: '30d'),
);

/// Order status options for the orders list filter chips. Pulled from
/// the backend so admins can add or rename statuses (e.g. introducing
/// `returned`) without a Flutter release. Falls back to a built-in
/// list if the endpoint isn't deployed yet — the fallback below mirrors
/// the web admin's status set so the two clients agree even during
/// the rollout window.
final orderStatusesProvider = FutureProvider<List<OrderStatusOption>>((ref) async {
  try {
    final list = await ref.watch(akhiyanApiProvider).orders.statuses();
    if (list.isNotEmpty) return list;
  } catch (_) {
    // Swallow — caller (and the UI) gets the fallback below.
  }
  // Mirrors the web admin's order-status filter dropdown. Once the
  // backend exposes GET /api/v1/m/orders/statuses, that response wins
  // and this list becomes a safety net only.
  return const <OrderStatusOption>[
    OrderStatusOption(key: 'pending', label: 'Pending'),
    OrderStatusOption(key: 'processing', label: 'Processing'),
    OrderStatusOption(key: 'on_hold', label: 'On Hold'),
    OrderStatusOption(key: 'confirmed', label: 'Confirmed'),
    OrderStatusOption(key: 'courier_sent', label: 'Courier Sent'),
  ];
});

/// Staff / admin accounts list. Powers the Staff tab on the Users screen.
/// Refreshed live by [syncInvalidationProvider] when the backend emits a
/// `staff` channel bump. Kept-alive (no autoDispose) so flipping tabs back
/// and forth is instant.
final staffListProvider = FutureProvider<List<StaffMember>>(
  (ref) => ref.watch(akhiyanApiProvider).staff.list(),
);
