import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import 'sync_client.dart';

/// App-root listener that invalidates resource providers when their SSE
/// channel bumps. This is the bridge between the network-level [SyncClient]
/// and the data-fetching providers in [api_providers.dart] / per-feature
/// modules — without it, a backend admin save would update the version map
/// but no UI screen would actually refetch.
///
/// Wired once at the top of the widget tree in [AkhiyanAdminApp]:
/// `ref.watch(syncInvalidationProvider)` — ProviderScope keeps it alive for
/// the app's lifetime.
///
/// To opt a NEW resource into live updates: add a `(channel, providers)`
/// row to the [_channels] map below. Each provider gets `ref.invalidate`'d
/// when its channel bumps; if the screen is currently watching it,
/// Riverpod refetches transparently. Screens already gone from memory pay
/// nothing.
final syncInvalidationProvider = Provider<void>((ref) {
  final invalidator = _SyncInvalidator(ref);
  ref.listen<SyncState>(syncClientProvider, (prev, next) {
    invalidator.onState(prev, next);
  }, fireImmediately: true);
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
      _invalidateForChannel(channel, version);
    });
  }

  /// Per-channel invalidation. Switch (instead of a `Map<String, List<…>>`)
  /// avoids fighting Riverpod 3's provider type-system: each provider has
  /// its own concrete type and they don't share a common supertype the
  /// analyzer is happy with in a List.
  ///
  /// To wire a NEW resource into live updates: add a `case` here calling
  /// the relevant `ref.invalidate(...)`. The /m/theme refetch is wired
  /// directly in `liveThemeProvider` via `ref.watch(syncVersionProvider)`
  /// so 'theme' isn't listed.
  void _invalidateForChannel(String channel, int version) {
    if (kDebugMode) debugPrint('[sync] bump $channel → $version');
    switch (channel) {
      case 'orders':
        _ref.invalidate(ordersListProvider);
        _ref.invalidate(dashboardDataProvider);
        break;
      case 'products':
        _ref.invalidate(productsListProvider);
        _ref.invalidate(inventoryListProvider);
        break;
      case 'customers':
        _ref.invalidate(customersListProvider);
        break;
      // 'reviews', 'banners', 'menus', 'flash-sales', 'settings' — no
      // listening providers wired yet; bumps recorded in the version map
      // for any future screen that watches them via syncVersionProvider.
      default:
        break;
    }
  }

  void dispose() => _disposed = true;
}
