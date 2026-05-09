import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/sync/sync_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
/// non-JSON. Mirrors the web admin sidebar structure 1:1 so the mobile
/// drawer feels identical. Items with a Flutter screen get a real
/// `mobileRoute`; items still pending mobile builds get
/// `mobileRoute: null`, which renders them greyed-out with a "coming
/// soon" snackbar on tap.
///
/// Should be kept roughly in sync with `src/lib/nav-tree.ts` on the
/// web admin. The two intentional omissions vs the web menu are
/// **Banners** and **Menus** (filtered via [_kHiddenNavLabels]).
const _kFallbackNav = LiveNav(
  groups: [
    LiveNavGroup(
      i18nKey: 'dashboard',
      label: 'Dashboard',
      icon: 'home',
      mobileRoute: '/dashboard',
    ),
    LiveNavGroup(
      i18nKey: 'products',
      label: 'Products',
      icon: 'shoppingBag',
      items: [
        LiveNavLeaf(
          i18nKey: 'productsList',
          label: 'Products',
          icon: 'package',
          webRoute: '/admin/products',
          mobileRoute: '/products',
        ),
        LiveNavLeaf(
          i18nKey: 'categories',
          label: 'Categories',
          icon: 'tag',
          webRoute: '/admin/categories',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'brands',
          label: 'Brands',
          icon: 'award',
          webRoute: '/admin/brands',
          mobileRoute: null,
        ),
      ],
    ),
    LiveNavGroup(
      i18nKey: 'orders',
      label: 'Orders',
      icon: 'shoppingCart',
      items: [
        LiveNavLeaf(
          i18nKey: 'ordersList',
          label: 'Orders',
          icon: 'shoppingCart',
          webRoute: '/admin/orders',
          mobileRoute: '/orders',
        ),
        LiveNavLeaf(
          i18nKey: 'incompleteOrders',
          label: 'Incomplete Orders',
          icon: 'shoppingCart',
          webRoute: '/admin/incomplete-orders',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'courierMonitor',
          label: 'Courier Monitor',
          icon: 'truck',
          webRoute: '/admin/courier',
          mobileRoute: '/courier',
        ),
        LiveNavLeaf(
          i18nKey: 'spamDetection',
          label: 'Spam Detection',
          icon: 'shield',
          webRoute: '/admin/fraud-security',
          mobileRoute: '/fraud-security',
        ),
      ],
    ),
    LiveNavGroup(
      i18nKey: 'customer',
      label: 'Customer',
      icon: 'users',
      items: [
        // The Flutter "Users" screen at /customers shows both customers
        // and staff via a role filter — same UX as the web "Users" page.
        LiveNavLeaf(
          i18nKey: 'users',
          label: 'Users',
          icon: 'users',
          webRoute: '/admin/customers',
          mobileRoute: '/customers',
        ),
        LiveNavLeaf(
          i18nKey: 'reviews',
          label: 'Reviews',
          icon: 'star',
          webRoute: '/admin/reviews',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'formSubmissions',
          label: 'Form Submissions',
          icon: 'mail',
          webRoute: '/admin/forms',
          mobileRoute: null,
        ),
      ],
    ),
    LiveNavGroup(
      i18nKey: 'marketing',
      label: 'Marketing',
      icon: 'zap',
      items: [
        LiveNavLeaf(
          i18nKey: 'flashSales',
          label: 'Flash Sales',
          icon: 'zap',
          webRoute: '/admin/flash-sales',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'coupons',
          label: 'Coupons',
          icon: 'percent',
          webRoute: '/admin/coupons',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'shortlinks',
          label: 'Shortlinks',
          icon: 'link',
          webRoute: '/admin/shortlinks',
          mobileRoute: '/shortlinks',
        ),
      ],
    ),
    // Top-level (no items) — matches the web admin which lists Landing
    // Pages and Product Feeds as flat sidebar entries, not under a group.
    // mobileRoute defaults to null → renders greyed-out "coming soon".
    LiveNavGroup(
      i18nKey: 'landingPages',
      label: 'Landing Pages',
      icon: 'layout',
    ),
    LiveNavGroup(
      i18nKey: 'productFeeds',
      label: 'Product Feeds',
      icon: 'rss',
    ),
    LiveNavGroup(
      i18nKey: 'settings',
      label: 'Settings',
      icon: 'settings',
      items: [
        LiveNavLeaf(
          i18nKey: 'customizer',
          label: 'Customizer',
          icon: 'droplet',
          webRoute: '/admin/customizer',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'shippingZones',
          label: 'Shipping Zones',
          icon: 'truck',
          webRoute: '/admin/settings/shipping-zones',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'siteSettings',
          label: 'Site Settings',
          icon: 'settings',
          webRoute: '/admin/settings',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'checkoutForm',
          label: 'Checkout Form',
          icon: 'shoppingCart',
          webRoute: '/admin/settings/checkout',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'courierSettings',
          label: 'Courier',
          icon: 'truck',
          webRoute: '/admin/settings/courier',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'email',
          label: 'Email',
          icon: 'mail',
          webRoute: '/admin/settings/email',
          mobileRoute: null,
        ),
        LiveNavLeaf(
          i18nKey: 'language',
          label: 'Language',
          icon: 'globe',
          webRoute: '/admin/settings/language',
          mobileRoute: null,
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

/// Maps the icon-name strings the backend emits to [LucideIcons] glyphs.
/// Names align with the `react-icons/fi` (Feather/Lucide) set used on the
/// web sidebar — same names, same strokes, identical visual on both
/// platforms. A missing mapping falls back to a neutral circle so a new
/// icon name added on the backend doesn't crash the drawer.
IconData navIconFor(String name) {
  switch (name) {
    case 'home':
      return LucideIcons.home;
    case 'box':
      return LucideIcons.box;
    case 'tag':
      return LucideIcons.tag;
    case 'award':
      return LucideIcons.award;
    case 'package':
      return LucideIcons.package;
    case 'shoppingBag':
      return LucideIcons.shoppingBag;
    case 'shoppingCart':
      return LucideIcons.shoppingCart;
    case 'truck':
      return LucideIcons.truck;
    case 'shield':
      return LucideIcons.shield;
    case 'users':
      return LucideIcons.users;
    case 'star':
      return LucideIcons.star;
    case 'mail':
      return LucideIcons.mail;
    case 'zap':
      return LucideIcons.zap;
    case 'percent':
      return LucideIcons.percent;
    case 'link':
      return LucideIcons.link;
    case 'layout':
      return LucideIcons.layout;
    case 'image':
      return LucideIcons.image;
    case 'menu':
      return LucideIcons.menu;
    case 'rss':
      return LucideIcons.rss;
    case 'fileText':
      return LucideIcons.fileText;
    case 'info':
      return LucideIcons.info;
    case 'refreshCw':
      return LucideIcons.refreshCw;
    case 'barChart':
      return LucideIcons.barChart;
    case 'bell':
      return LucideIcons.bell;
    case 'settings':
      return LucideIcons.settings;
    case 'droplet':
      return LucideIcons.droplet;
    case 'globe':
      return LucideIcons.globe;
    case 'chevronRight':
      return LucideIcons.chevronRight;
    case 'chevronDown':
      return LucideIcons.chevronDown;
    default:
      return LucideIcons.circle;
  }
}
