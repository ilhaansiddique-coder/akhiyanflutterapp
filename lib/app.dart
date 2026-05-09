import 'package:akhiyan_admin/src/core/notifications/notification_store.dart';
import 'package:akhiyan_admin/src/core/router/app_router.dart';
import 'package:akhiyan_admin/src/core/sync/sync_invalidation.dart';
import 'package:akhiyan_admin/src/core/theme/live_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AkhiyanAdminApp extends ConsumerWidget {
  const AkhiyanAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mount the SSE invalidation listener once at the root so live updates
    // from the backend (admin saves a banner, an order comes in, theme
    // colour changes, etc.) reach every subscribed screen without each
    // screen needing its own subscription.
    ref.watch(syncInvalidationProvider);
    // Same reason for the notification store: it ingests SSE events with
    // a `notify` payload into the in-app notification panel even when the
    // bell screen isn't currently open. Without this read here it would
    // build lazily on first navigation and miss earlier events.
    ref.watch(notificationStoreProvider);

    final router = ref.watch(appRouterProvider);
    final theme = ref.watch(activeThemeDataProvider);
    return MaterialApp.router(
      title: 'Akhiyan Admin',
      debugShowCheckedModeBanner: false,
      theme: theme,
      scrollBehavior: const _AppScrollBehavior(),
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}

/// Smooth, iOS-style scroll on every platform.
///
/// `BouncingScrollPhysics` rubber-bands at edges instead of dead-stopping
/// (the old Android `ClampingScrollPhysics` + glow flash felt harsh — that
/// glow has been removed because the bounce already conveys the limit).
/// `AlwaysScrollableScrollPhysics` parent keeps short content rebound-able
/// too — useful for pull-to-refresh later.
///
/// `dragDevices` adds mouse/trackpad/stylus so drag-scrolling works on
/// desktop and the web Chrome preview, not just touch.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // The bounce rebound already shows the user they hit the edge — no
    // need for the bright primary-tinted glow flash on top.
    return child;
  }
}
