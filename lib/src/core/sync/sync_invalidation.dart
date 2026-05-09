import 'package:akhiyan_admin/app.dart' show AkhiyanAdminApp;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/sync/sync_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-root listener that refreshes resource providers when their SSE
/// channel bumps. This is the bridge between the network-level [SyncClient]
/// and the data-fetching providers in [api_providers.dart] / per-feature
/// modules — without it, a backend admin save would update the version map
/// but no UI screen would actually refetch.
///
/// **Why eager refresh, not lazy invalidate.** `ref.invalidate(provider)` is
/// lazy — it just marks the provider as stale; the actual rebuild only
/// happens on the next `ref.watch`. For our kept-alive list providers
/// (no autoDispose) this means: when a new order arrives while the user is
/// on the dashboard tab, the orders list is "marked stale" but its
/// in-memory `_pageCache` still holds the old page-1 data. When the user
/// taps the Orders tab seconds later, Riverpod returns the OLD state for
/// one frame before the rebuild starts — so the new order doesn't appear
/// until the user pulls to refresh.
///
/// Calling `notifier.refresh()` explicitly clears the page cache and
/// kicks off an immediate fetch, regardless of who's watching. The result
/// is "go to a screen, see the new order already there" — true real-time.
///
/// Wired once at the top of the widget tree in [AkhiyanAdminApp]:
/// `ref.watch(syncInvalidationProvider)` — ProviderScope keeps it alive for
/// the app's lifetime.
final syncInvalidationProvider = Provider<void>((ref) {
  final invalidator = _SyncInvalidator(ref);
  ref.listen<SyncState>(syncClientProvider, invalidator.onState, fireImmediately: true);
  ref.onDispose(invalidator.dispose);
});

class _SyncInvalidator {
  _SyncInvalidator(this._ref);

  final Ref _ref;

  /// Last seen version per channel. We only fire `invalidate` on an actual
  /// version change — receiving the same number twice (e.g. on reconnect
  /// snapshot) shouldn't trigger spurious refetches.
  final Map<String, int> _seen = {};
  bool _disposed = false;

  void onState(SyncState? prev, SyncState next) {
    if (_disposed) return;
    next.versions.forEach((channel, version) {
      final last = _seen[channel] ?? 0;
      if (version <= last) return;
      _seen[channel] = version;
      // Defer to a microtask: ref.listen callbacks fire synchronously while
      // the source notifier is still publishing. If multiple channels bump
      // back-to-back (initial SSE snapshot), invalidating providers inline
      // rebuilds dependants like syncVersionProvider twice in the same frame
      // — Riverpod 3 throws "Tried to rebuild Provider<int> multiple times
      // in the same frame". Microtask breaks the chain.
      Future.microtask(() {
        if (_disposed) return;
        _refreshForChannel(channel, version);
      });
    });
  }

  /// Per-channel eager refresh. Switch (instead of a `Map<String, …>`)
  /// avoids fighting Riverpod 3's provider type-system: each provider has
  /// its own concrete type and they don't share a common supertype the
  /// analyzer is happy with in a List.
  ///
  /// To wire a NEW resource into live updates: add a `case` here calling
  /// the relevant `notifier.refresh()` (for paged Notifiers) or
  /// `ref.invalidate(...)` (for FutureProviders). The /m/theme refetch
  /// is wired directly in `liveThemeProvider` via
  /// `ref.watch(syncVersionProvider)` so 'theme' isn't listed.
  void _refreshForChannel(String channel, int version) {
    if (kDebugMode) debugPrint('[sync] bump $channel -> $version, refreshing');
    switch (channel) {
      case 'orders':
        // SinglePageNotifier.refresh() clears _pageCache and refetches the
        // current page eagerly — that's what makes the new order appear on
        // the orders screen and the dashboard's recent-orders strip without
        // a manual pull-to-refresh.
        _ref.read(ordersListProvider.notifier).refresh();
        // The dashboard payload is a FutureProvider.family keyed by
        // DateTimeRange. Invalidate the whole family so any open dashboard
        // screen (regardless of date range) refetches; family-level
        // invalidate is supported in Riverpod 3 and propagates to all
        // currently-built keys.
        _ref.invalidate(dashboardDataProvider);
        // Charts (bar + donut) on the dashboard read from
        // dashboardAnalyticsProvider (period=7d), and the standalone
        // analytics screen reads from analyticsDataProvider (period=30d).
        // Both windows include the just-arrived order, so refetch them
        // alongside the dashboard payload — otherwise the bars and the
        // status donut lag behind the recent-orders list by a refresh.
        _ref.invalidate(dashboardAnalyticsProvider);
        _ref.invalidate(analyticsDataProvider);
      case 'products':
        _ref.read(productsListProvider.notifier).refresh();
        // Inventory mirrors product stock; refresh that page too.
        _ref.read(inventoryListProvider.notifier).refresh();
        // Dashboard "Top Products" depends on product changes too.
        _ref.invalidate(dashboardDataProvider);
        // Variant cache used by the order form's product picker — drop the
        // family so a re-opened variant sheet sees the updated variants
        // (added/removed, price changed, stock changed).
        _ref.invalidate(productDetailProvider);
      case 'customers':
        _ref.read(customersListProvider.notifier).refresh();
      case 'staff':
        _ref.invalidate(staffListProvider);
      case 'categories':
        // FutureProvider with no autoDispose — invalidate is enough; the
        // categories screen watches via ref.watch and rebuilds on next frame.
        _ref.invalidate(categoriesProvider);
      case 'brands':
        _ref.invalidate(brandsProvider);
      case 'landing-pages':
        _ref.invalidate(landingPagesProvider);
        // Drop the detail family too — if the edit screen is open while
        // another admin saves, it'll re-fetch the canonical shape.
        _ref.invalidate(landingPageDetailProvider);
      case 'feeds':
        _ref.invalidate(feedConfigProvider);
      case 'coupons':
        _ref.invalidate(couponsProvider);
      case 'flash-sales':
        _ref.invalidate(flashSalesProvider);
      case 'settings':
        // Drives the SettingsScreen's editable forms (Site, Checkout,
        // Courier, Email, Language). The `theme` channel keeps its own
        // dedicated path through liveThemeProvider so a colour-only
        // change doesn't force a full settings refetch.
        _ref.invalidate(adminSettingsProvider);
      // 'reviews', 'banners', 'menus', 'flash-sales', 'settings' — no
      // listening providers wired yet; bumps recorded in the version map
      // for any future screen that watches them via syncVersionProvider.
      default:
        break;
    }
  }

  void dispose() => _disposed = true;
}
