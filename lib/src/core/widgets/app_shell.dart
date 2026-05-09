import 'package:akhiyan_admin/src/core/router/app_router.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/create_menu.dart';
import 'package:akhiyan_admin/src/features/orders/application/orders_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
///
/// The bottom bar + FAB live OUTSIDE the drawer's scrim by default — the
/// Scaffold draws them over the drawer when it opens. We track drawer
/// open/close via [Scaffold.onDrawerChanged] and hide both while the
/// drawer is visible so the side menu reads as a true full-height overlay
/// (matching the web admin's sidebar that obscures everything beneath it).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _drawerOpen = false;

  // Lucide doesn't ship paired outline+filled variants the way Material
  // does, so selected/unselected uses the same glyph and the active state
  // is conveyed via colour + weight on the label below the icon.
  static const _destinations = <_NavDest>[
    _NavDest(AppRoute.dashboard, LucideIcons.layoutDashboard,
        LucideIcons.layoutDashboard, 'Dashboard'),
    _NavDest(AppRoute.orders, LucideIcons.shoppingCart,
        LucideIcons.shoppingCart, 'Orders'),
    _NavDest(AppRoute.products, LucideIcons.package,
        LucideIcons.package, 'Products'),
    _NavDest(AppRoute.marketing, LucideIcons.megaphone,
        LucideIcons.megaphone, 'Marketing'),
  ];

  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final i = _destinations.indexWhere((d) => loc.startsWith(d.route.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _indexFor(context);
    final pendingOrders = ref.watch(pendingOrdersCountProvider);

    return Scaffold(
      key: appShellScaffoldKey,
      // Body extends under the BottomAppBar so the bar's circular notch
      // (around the docked FAB) shows the body through it instead of the
      // scaffold's default white background. Critical when a modal sheet
      // dims the screen — without this, the notch cuts a white "hole"
      // through the dim layer.
      extendBody: true,
      drawer: const AppDrawer(),
      onDrawerChanged: (open) {
        if (mounted) setState(() => _drawerOpen = open);
      },
      body: widget.child,
      // Center-docked FAB sits in the BottomAppBar's notch. The bar's
      // `shape: CircularNotchedRectangle()` carves out the space.
      // FAB stays brand-primary so it pops against any screen background
      // when scrolled past, while the bar around it is also primary —
      // the visible curved gap (notchMargin: 14) is what separates them
      // visually, matching the reference design.
      // Hide the FAB while the drawer is open — without this it stays
      // docked into the bottom bar and floats over the drawer's right
      // edge, breaking the "drawer covers everything" illusion.
      floatingActionButton: _drawerOpen
          ? null
          : FloatingActionButton(
              onPressed: () => openCreateMenu(context),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 6,
              shape: const CircleBorder(),
              tooltip: 'Create',
              child: const Icon(LucideIcons.plus, size: 28),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _drawerOpen ? null : BottomAppBar(
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
    const activeColor = AppColors.onPrimary;
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
            if (badgeCount > 0) Badge(
                    backgroundColor: AppColors.error,
                    textColor: AppColors.onError,
                    smallSize: 8,
                    child: iconWidget,
                  ) else iconWidget,
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
