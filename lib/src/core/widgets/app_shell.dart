import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/orders/application/orders_providers.dart';
import '../router/app_router.dart';
import '../theme/colors.dart';
import 'app_drawer.dart';

/// Global key for the shell's Scaffold so the hamburger button on the inner
/// feature screens' `AppShellAppBar` can open the OUTER (shell) drawer —
/// `Scaffold.of(context)` from inside a feature screen would otherwise resolve
/// to the inner Scaffold which has no drawer attached.
final appShellScaffoldKey = GlobalKey<ScaffoldState>();

/// Shell for the main tabs — wraps the active route with a Material 3
/// [NavigationBar] at the bottom and a left-side [AppDrawer].
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _destinations = <_NavDest>[
    _NavDest(AppRoute.dashboard, Icons.dashboard_outlined,
        Icons.dashboard, 'Dashboard'),
    _NavDest(AppRoute.orders, Icons.shopping_cart_outlined,
        Icons.shopping_cart, 'Orders'),
    _NavDest(AppRoute.products, Icons.inventory_2_outlined,
        Icons.inventory_2, 'Products'),
    _NavDest(AppRoute.marketing, Icons.campaign_outlined,
        Icons.campaign, 'Marketing'),
  ];

  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final i = _destinations.indexWhere((d) => loc.startsWith(d.route.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = _indexFor(context);
    final pendingOrders = ref.watch(pendingOrdersCountProvider);

    Widget wrapWithBadge(_NavDest d, IconData icon) {
      final base = Icon(icon);
      if (d.route == AppRoute.orders && pendingOrders > 0) {
        return Badge(
          backgroundColor: AppColors.error,
          smallSize: 8,
          child: base,
        );
      }
      return base;
    }

    return Scaffold(
      key: appShellScaffoldKey,
      drawer: const AppDrawer(),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => context.go(_destinations[i].route.path),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: wrapWithBadge(d, d.icon),
              selectedIcon: wrapWithBadge(d, d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _NavDest {
  const _NavDest(this.route, this.icon, this.selectedIcon, this.label);
  final AppRoute route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
