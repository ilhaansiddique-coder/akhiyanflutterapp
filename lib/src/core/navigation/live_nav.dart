import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/sync/sync_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Decoded payload from `GET /api/v1/m/ui/nav`.
///
/// The backend sources this from `src/lib/nav-tree.ts`, so the Flutter
/// sidebar mirrors the web dashboard sidebar without duplicating the menu
/// definition. Icons arrive as STRING NAMES (e.g. `"shoppingBag"`) and
/// are resolved to [IconData] via [navIconFor] at render time.
@immutable
class LiveNavLeaf {
  const LiveNavLeaf({
    required this.i18nKey,
    required this.label,
    required this.icon,
    required this.webRoute,
    required this.mobileRoute,
  });

  factory LiveNavLeaf.fromJson(Map<String, dynamic> json) => LiveNavLeaf(
        i18nKey: (json['i18nKey'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        icon: (json['icon'] ?? '').toString(),
        webRoute: (json['webRoute'] ?? '').toString(),
        mobileRoute: json['mobileRoute'] as String?,
      );

  final String i18nKey;
  final String label;
  final String icon;
  final String webRoute;

  /// Flutter go_router route, or `null` if the screen isn't built yet.
  /// `null` items render disabled and surface a "Coming soon" snackbar on tap.
  final String? mobileRoute;

  bool get enabled => mobileRoute != null && mobileRoute!.isNotEmpty;
}

@immutable
class LiveNavGroup {
  const LiveNavGroup({
    required this.i18nKey,
    required this.label,
    required this.icon,
    this.webRoute,
    this.mobileRoute,
    this.items = const [],
  });

  factory LiveNavGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(LiveNavLeaf.fromJson)
            .toList(growable: false)
        : const <LiveNavLeaf>[];
    return LiveNavGroup(
      i18nKey: (json['i18nKey'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      webRoute: json['webRoute'] as String?,
      mobileRoute: json['mobileRoute'] as String?,
      items: items,
    );
  }

  final String i18nKey;
  final String label;
  final String icon;
  final String? webRoute;
  final String? mobileRoute;
  final List<LiveNavLeaf> items;

  bool get isLeaf => items.isEmpty;
  bool get enabled => mobileRoute != null && mobileRoute!.isNotEmpty;
}

@immutable
class LiveNav {
  const LiveNav({required this.groups});

  factory LiveNav.fromJson(Map<String, dynamic> json) {
    final raw = json['groups'];
    final groups = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(LiveNavGroup.fromJson)
            .toList(growable: false)
        : const <LiveNavGroup>[];
    return LiveNav(groups: groups);
  }

  final List<LiveNavGroup> groups;

  static const empty = LiveNav(groups: []);
}

/// Labels (case-insensitive) the Flutter app hides from the sidebar even
/// when the backend ships them. Use this for items that exist in the web
/// admin but won't have a Flutter screen anytime soon — better than
/// rendering them greyed-out forever. Backend should still be the source
/// of truth long-term; remove from `src/lib/nav-tree.ts` once aligned.
const _kHiddenNavLabels = <String>{
  'banners',
  'menus',
};

bool _isHidden(String label) =>
    _kHiddenNavLabels.contains(label.trim().toLowerCase());

/// Filters out hidden labels from a [LiveNav] tree:
///  - drops any group whose label is hidden, AND
///  - drops any leaf whose label is hidden inside the surviving groups.
LiveNav _filterHidden(LiveNav nav) {
  final groups = <LiveNavGroup>[];
  for (final g in nav.groups) {
    if (_isHidden(g.label)) continue;
    final items = g.items.where((it) => !_isHidden(it.label)).toList(
          growable: false,
        );
    groups.add(
      LiveNavGroup(
        i18nKey: g.i18nKey,
        label: g.label,
        icon: g.icon,
        webRoute: g.webRoute,
        mobileRoute: g.mobileRoute,
        items: items,
      ),
    );
  }
  return LiveNav(groups: groups);
}

/// Hardcoded fallback shown when `/ui/nav` is unreachable or returns
/// non-JSON. Without this the entire sidebar errors out the moment the
/// backend hiccups (Coolify cold-start, route undeployed, network blip).
/// Mirrors the production menu structure as of 2026-05; should be kept
/// roughly in sync with `src/lib/nav-tree.ts` on the web admin.
const _kFallbackNav = LiveNav(
  groups: [
    LiveNavGroup(
      i18nKey: 'dashboard',
      label: 'Dashboard',
      icon: 'home',
      mobileRoute: '/dashboard',
    ),
    LiveNavGroup(
      i18nKey: 'productManagement',
      label: 'Product Management',
      icon: 'shoppingBag',
      items: [
        LiveNavLeaf(
          i18nKey: 'products',
          label: 'Products',
          icon: 'package',
          webRoute: '/admin/products',
          mobileRoute: '/products',
        ),
        LiveNavLeaf(
          i18nKey: 'inventory',
          label: 'Inventory',
          icon: 'box',
          webRoute: '/admin/inventory',
          mobileRoute: '/inventory',
        ),
      ],
    ),
    LiveNavGroup(
      i18nKey: 'orderManagement',
      label: 'Order Management',
      icon: 'shoppingCart',
      items: [
        LiveNavLeaf(
          i18nKey: 'orders',
          label: 'Orders',
          icon: 'shoppingCart',
          webRoute: '/admin/orders',
          mobileRoute: '/orders',
        ),
        LiveNavLeaf(
          i18nKey: 'courier',
          label: 'Courier',
          icon: 'truck',
          webRoute: '/admin/courier',
          mobileRoute: '/courier',
        ),
        LiveNavLeaf(
          i18nKey: 'fraud',
          label: 'Fraud & Security',
          icon: 'shield',
          webRoute: '/admin/fraud',
          mobileRoute: '/fraud-security',
        ),
      ],
    ),
    LiveNavGroup(
      i18nKey: 'customer',
      label: 'Customer',
      icon: 'users',
      items: [
        LiveNavLeaf(
          i18nKey: 'customers',
          label: 'Customers',
          icon: 'users',
          webRoute: '/admin/customers',
          mobileRoute: '/customers',
        ),
        LiveNavLeaf(
          i18nKey: 'staff',
          label: 'Staff',
          icon: 'users',
          webRoute: '/admin/staff',
          mobileRoute: '/staff',
        ),
      ],
    ),
    LiveNavGroup(
      i18nKey: 'marketing',
      label: 'Marketing',
      icon: 'zap',
      items: [
        LiveNavLeaf(
          i18nKey: 'shortlinks',
          label: 'Shortlinks',
          icon: 'link',
          webRoute: '/admin/shortlinks',
          mobileRoute: '/shortlinks',
        ),
      ],
    ),
    LiveNavGroup(
      i18nKey: 'analytics',
      label: 'Analytics',
      icon: 'barChart',
      mobileRoute: '/analytics',
    ),
    LiveNavGroup(
      i18nKey: 'notifications',
      label: 'Notifications',
      icon: 'bell',
      mobileRoute: '/notifications',
    ),
  ],
);

/// Fetches `/api/v1/m/ui/nav`. Refetches when the `settings` channel bumps
/// so future role-gating or feature-flag changes propagate without an app
/// restart. Theme changes flow through `liveThemeProvider` separately.
///
/// **Resilience:** if the request fails (404, timeout, non-JSON, network
/// down), falls back to [_kFallbackNav] so the drawer still works. We
/// never let a transient backend issue break the entire sidebar.
final liveNavProvider = FutureProvider<LiveNav>((ref) async {
  ref.watch(syncVersionProvider('settings'));
  final api = ref.watch(akhiyanApiProvider);
  try {
    final res = await api.request('GET', '/ui/nav') as Map<String, dynamic>;
    return _filterHidden(LiveNav.fromJson(res));
  } on Exception {
    // Backend unreachable or returned a non-JSON error page (404 HTML, etc).
    // Fall back to the bundled menu — degraded mode but the app stays usable.
    return _filterHidden(_kFallbackNav);
  }
});

/// Maps the Lucide-style icon-name strings the backend emits to Flutter
/// Material icons. Names align with the `react-icons/fi` set used on the
/// web sidebar so designers don't have to maintain two name lists.
IconData navIconFor(String name) {
  switch (name) {
    case 'home':
      return Icons.home_outlined;
    case 'box':
      return Icons.inventory_2_outlined;
    case 'tag':
      return Icons.local_offer_outlined;
    case 'award':
      return Icons.emoji_events_outlined;
    case 'package':
      return Icons.all_inbox_outlined;
    case 'shoppingBag':
      return Icons.shopping_bag_outlined;
    case 'shoppingCart':
      return Icons.shopping_cart_outlined;
    case 'truck':
      return Icons.local_shipping_outlined;
    case 'shield':
      return Icons.shield_outlined;
    case 'users':
      return Icons.people_outline;
    case 'star':
      return Icons.star_border;
    case 'mail':
      return Icons.mail_outline;
    case 'zap':
      return Icons.bolt_outlined;
    case 'percent':
      return Icons.percent_outlined;
    case 'link':
      return Icons.link_outlined;
    case 'layout':
      return Icons.dashboard_outlined;
    case 'image':
      return Icons.image_outlined;
    case 'menu':
      return Icons.menu;
    case 'rss':
      return Icons.rss_feed_outlined;
    case 'fileText':
      return Icons.description_outlined;
    case 'info':
      return Icons.info_outline;
    case 'refreshCw':
      return Icons.refresh_outlined;
    case 'barChart':
      return Icons.bar_chart_outlined;
    case 'bell':
      return Icons.notifications_outlined;
    case 'settings':
      return Icons.settings_outlined;
    case 'droplet':
      return Icons.water_drop_outlined;
    case 'globe':
      return Icons.language_outlined;
    case 'chevronRight':
      return Icons.chevron_right;
    case 'chevronDown':
      return Icons.expand_more;
    default:
      return Icons.circle_outlined;
  }
}
