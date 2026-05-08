import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/orders/application/orders_providers.dart';
import '../router/app_router.dart';
import '../theme/colors.dart';
import 'app_drawer.dart';
import 'create_menu.dart';

/// Global key for the shell's Scaffold so the hamburger button on the inner
/// feature screens' `AppShellAppBar` can open the OUTER (shell) drawer —
/// `Scaffold.of(context)` from inside a feature screen would otherwise resolve
/// to the inner Scaffold which has no drawer attached.
final appShellScaffoldKey = GlobalKey<ScaffoldState>();

/// Shell for the main tabs.
///
/// Bottom UI is a notched [BottomAppBar] with two destinations on each
/// side of a centered, elevated [FloatingActionButton] that opens the
/// global "Create" sheet. We deliberately moved away from
/// [NavigationBar] so we can dock the FAB into the bar — the create
/// affordance becomes the visual anchor of the app, reachable from
/// every screen.
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

    return Scaffold(
      key: appShellScaffoldKey,
      drawer: const AppDrawer(),
      body: child,
      // Center-docked FAB sits in the BottomAppBar's notch. The bar's
      // `shape: CircularNotchedRectangle()` carves out the space.
      // FAB stays brand-primary so it pops against any screen background
      // when scrolled past, while the bar around it is also primary —
      // the visible curved gap (notchMargin: 14) is what separates them
      // visually, matching the reference design.
      floatingActionButton: FloatingActionButton(
        onPressed: () => openCreateMenu(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 6,
        shape: const CircleBorder(),
        tooltip: 'Create',
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.primary,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        // Curved gap around the docked FAB. Tuned visually: ~10px reads
        // as a clear wrap without the gap dominating the bar.
        notchMargin: 10,
        padding: const EdgeInsets.symmetric(vertical: 10),
        height: 76,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              dest: _destinations[0],
              isSelected: selected == 0,
              badgeCount: 0,
            ),
            _NavItem(
              dest: _destinations[1],
              isSelected: selected == 1,
              badgeCount: pendingOrders,
            ),
            // Spacer reserves the notch width so the FAB has clearance.
            const SizedBox(width: 56),
            _NavItem(
              dest: _destinations[2],
              isSelected: selected == 2,
              badgeCount: 0,
            ),
            _NavItem(
              dest: _destinations[3],
              isSelected: selected == 3,
              badgeCount: 0,
            ),
          ],
        ),
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

/// A single bottom-nav item. Manages its own selected state styling
/// (icon swap + tinted label) and its own `Badge` for unread counts.
/// Tap navigates via go_router so the back stack stays clean.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.dest,
    required this.isSelected,
    required this.badgeCount,
  });

  final _NavDest dest;
  final bool isSelected;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    // Bar background is brand primary, so items use onPrimary (white).
    // Selected = full opacity, unselected = 65% so the active tab still
    // reads at a glance even when both colours are the same hue.
    final activeColor = AppColors.onPrimary;
    final color = isSelected
        ? activeColor
        : activeColor.withValues(alpha: 0.65);
    final iconWidget = Icon(
      isSelected ? dest.selectedIcon : dest.icon,
      color: color,
      size: 22,
    );
    return Expanded(
      child: InkResponse(
        onTap: () => context.go(dest.route.path),
        radius: 28,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            badgeCount > 0
                ? Badge(
                    backgroundColor: AppColors.error,
                    textColor: AppColors.onError,
                    smallSize: 8,
                    child: iconWidget,
                  )
                : iconWidget,
            const SizedBox(height: 4),
            Text(
              dest.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
