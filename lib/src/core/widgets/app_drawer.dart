import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/navigation/live_nav.dart';
import 'package:akhiyan_admin/src/core/router/app_router.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/live_theme.dart';
import 'package:akhiyan_admin/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Side drawer modelled on the web dashboard sidebar
/// (`src/components/DashboardLayout.tsx`).
///
/// Drawn entirely on top of the live primary colour so a Customizer change
/// on the web admin re-paints the sidebar in real time over SSE — no app
/// restart, no manual refresh. The nav tree itself is also fetched from
/// the server (`/api/v1/m/ui/nav`) so adding/renaming menu items is a
/// server-side edit, not a Flutter release.
///
/// Items whose backing screen has not been built in Flutter yet render
/// disabled (low-opacity) and surface a "Coming soon" snackbar on tap, so
/// the menu structure stays visually identical to the web admin even
/// before every screen has a mobile equivalent.
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  /// Per-group expanded/collapsed flags. Auto-expands the group containing
  /// the current route so the user lands on a sensible default state.
  final Map<String, bool> _openGroups = {};

  @override
  Widget build(BuildContext context) {
    final navAsync = ref.watch(liveNavProvider);
    final themeAsync = ref.watch(liveThemeProvider);

    // Resolve primary from the live theme; fall back to the static brand
    // colour while the first fetch resolves.
    final Color primary = themeAsync.maybeWhen(
      data: (t) => t.colorOr('primary', AppColors.primary),
      orElse: () => AppColors.primary,
    );
    final String? logoUrl = themeAsync.maybeWhen(
      data: (t) => t.branding['site_logo'],
      orElse: () => null,
    );

    return Drawer(
      backgroundColor: primary,
      width: 280,
      child: SafeArea(
        child: navAsync.when(
          data: (nav) => _SidebarBody(
            nav: nav,
            primary: primary,
            logoUrl: logoUrl,
            openGroups: _openGroups,
            onToggleGroup: (label) {
              setState(() {
                _openGroups[label] = !(_openGroups[label] ?? false);
              });
            },
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Failed to load menu.\n$e',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

/// The actual sidebar contents. Split out so the AsyncValue-loading wrapper
/// in [_AppDrawerState] stays small and the body widget can take the nav
/// and theme tokens as plain inputs.
class _SidebarBody extends ConsumerWidget {
  const _SidebarBody({
    required this.nav,
    required this.primary,
    required this.logoUrl,
    required this.openGroups,
    required this.onToggleGroup,
  });

  final LiveNav nav;
  final Color primary;
  final String? logoUrl;
  final Map<String, bool> openGroups;
  final ValueChanged<String> onToggleGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final asyncUser = ref.watch(currentUserProvider);
    final session = ref.watch(authControllerProvider);
    final user = asyncUser.value;
    final name = user?.name ?? session?.name ?? '';
    final email = user?.email ?? '';

    return Column(
      children: [
        _Header(logoUrl: logoUrl),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: [
              for (final group in _filterGroups(nav.groups))
                _NavGroup(
                  group: group,
                  currentRoute: currentRoute,
                  isOpen: openGroups[group.label] ??
                      _isGroupActive(group, currentRoute),
                  onToggle: () => onToggleGroup(group.label),
                ),
            ],
          ),
        ),
        _Footer(name: name, email: email),
        const _BuildInfo(),
      ],
    );
  }

  /// Drop entries the mobile app doesn't surface: Content, Banner, Menu,
  /// and the Customizer settings sub-item. The server-side nav tree still
  /// lists them for the web admin; we hide them here so adding/removing
  /// stays a single client change.
  static const _hiddenLabels = {'content', 'banner', 'menu', 'customizer'};

  static List<LiveNavGroup> _filterGroups(List<LiveNavGroup> groups) {
    final out = <LiveNavGroup>[];
    for (final g in groups) {
      if (_hiddenLabels.contains(g.label.trim().toLowerCase())) continue;
      if (g.isLeaf) {
        out.add(g);
        continue;
      }
      final keptItems = g.items
          .where((i) => !_hiddenLabels.contains(i.label.trim().toLowerCase()))
          .toList(growable: false);
      if (keptItems.isEmpty) continue;
      out.add(LiveNavGroup(
        i18nKey: g.i18nKey,
        label: g.label,
        icon: g.icon,
        webRoute: g.webRoute,
        mobileRoute: g.mobileRoute,
        items: keptItems,
      ));
    }
    return out;
  }

  static bool _isGroupActive(LiveNavGroup g, String currentRoute) {
    if (g.isLeaf) return false;
    return g.items.any(
      (i) =>
          i.mobileRoute != null &&
          (currentRoute == i.mobileRoute ||
              currentRoute.startsWith('${i.mobileRoute}/')),
    );
  }
}

/// Logo strip pinned to the top of the sidebar. Mirrors the web sidebar's
/// centered logo block. Falls back to the wordmark in [_BrandFallback]
/// when the live theme has no `site_logo` (e.g., before first fetch).
class _Header extends StatelessWidget {
  const _Header({required this.logoUrl});
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white24, width: 1)),
      ),
      child: Center(
        child: SizedBox(
          height: 40,
          child: (logoUrl != null && logoUrl!.isNotEmpty)
              ? Image.network(
                  logoUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const _BrandFallback(),
                )
              : const _BrandFallback(),
        ),
      ),
    );
  }
}

/// Bundled logo used until/unless the live theme provides a `site_logo` URL,
/// or when that URL fails to load (offline first launch, broken CDN entry).
/// `assets/branding/akhiyan_logo.png` is already registered in pubspec.yaml.
class _BrandFallback extends StatelessWidget {
  const _BrandFallback();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/akhiyan_logo.png',
      fit: BoxFit.contain,
      // If the asset is somehow missing too, fall back to a wordmark — this
      // path should never trigger in production but keeps the drawer from
      // showing a broken-image icon if something goes wrong with bundling.
      errorBuilder: (_, _, _) => const Text(
        'AKHIYAN',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

/// One nav group — either a flat top-level link (`isLeaf`) or a
/// collapsible parent with child leaves underneath.
class _NavGroup extends StatelessWidget {
  const _NavGroup({
    required this.group,
    required this.currentRoute,
    required this.isOpen,
    required this.onToggle,
  });

  final LiveNavGroup group;
  final String currentRoute;
  final bool isOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (group.isLeaf) {
      final route = group.mobileRoute;
      final isActive =
          route != null && _routeMatches(currentRoute, route);
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: _NavTile(
          icon: navIconFor(group.icon),
          label: group.label,
          isActive: isActive,
          enabled: group.enabled,
          onTap: () => _navigate(context, route, group.label),
        ),
      );
    }

    final groupActive = group.items.any(
      (i) =>
          i.mobileRoute != null && _routeMatches(currentRoute, i.mobileRoute!),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavTile(
            icon: navIconFor(group.icon),
            label: group.label,
            isActive: groupActive,
            enabled: true,
            trailing: Icon(
              isOpen ? Icons.expand_more : Icons.chevron_right,
              size: 18,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            onTap: onToggle,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: ClipRect(
              child: !isOpen
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(left: 16, top: 2),
                      child: Column(
                        children: [
                          for (final item in group.items)
                            _NavTile(
                              icon: navIconFor(item.icon),
                              label: item.label,
                              isActive: item.mobileRoute != null &&
                                  _routeMatches(
                                      currentRoute, item.mobileRoute!),
                              enabled: item.enabled,
                              dense: true,
                              onTap: () => _navigate(
                                  context, item.mobileRoute, item.label),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _routeMatches(String current, String target) =>
      current == target || current.startsWith('$target/');

  static void _navigate(BuildContext context, String? route, String label) {
    Navigator.of(context).pop();
    if (route == null || route.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$label" coming soon to mobile.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    context.go(route);
  }
}

/// A single sidebar row. Reused for both top-level entries and nested
/// children (`dense` shrinks the row + icon for the nested case).
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.enabled,
    required this.onTap,
    this.dense = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool enabled;
  final bool dense;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color fg = !enabled
        ? Colors.white.withValues(alpha: 0.35)
        : isActive
            ? Colors.white
            : Colors.white.withValues(alpha: 0.78);
    final Color? bg = isActive ? Colors.white.withValues(alpha: 0.18) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: dense ? 16 : 18, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: dense ? 13 : 14,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer with current user + sign-out. Sign-out lives here because the
/// mobile shell has no top-bar to host it (unlike the web admin).
class _Footer extends ConsumerWidget {
  const _Footer({required this.name, required this.email});
  final String name;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white24, width: 1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: Icon(Icons.logout,
                color: Colors.white.withValues(alpha: 0.85), size: 20),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authControllerProvider.notifier).signOut();
              context.go(AppRoute.login.path);
            },
          ),
        ],
      ),
    );
  }
}

/// Tiny build/patch indicator shown under the user row.
///
/// On a Shorebird-built APK this shows e.g. `v1.0.0+2 · patch 5`. On a
/// regular `flutter build apk` (Shorebird runtime not present) it falls
/// back to `v1.0.0+2 · base`. Reading this off the drawer is the fastest
/// way to confirm "is this phone actually running the latest patch?"
class _BuildInfo extends StatefulWidget {
  const _BuildInfo();

  @override
  State<_BuildInfo> createState() => _BuildInfoState();
}

class _BuildInfoState extends State<_BuildInfo> {
  // Hardcoded so we don't depend on the package_info_plus plugin (which
  // would require a fresh APK build to add). Bump this string in lockstep
  // with `pubspec.yaml`'s `version:` field at every new APK release.
  static const _releaseVersion = '1.0.0+2';

  final _updater = ShorebirdUpdater();
  String _patchLabel = '…';

  @override
  void initState() {
    super.initState();
    _readPatch();
  }

  Future<void> _readPatch() async {
    try {
      final patch = await _updater.readCurrentPatch();
      if (!mounted) return;
      setState(() {
        _patchLabel = patch == null ? 'base' : 'patch ${patch.number}';
      });
    } on Exception {
      if (!mounted) return;
      // Updater not available (running on a non-Shorebird build, e.g. the
      // dev `flutter run`). Show "base" so the row still renders cleanly.
      setState(() => _patchLabel = 'base');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        'v$_releaseVersion · $_patchLabel',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
