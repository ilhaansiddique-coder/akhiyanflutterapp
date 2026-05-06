import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/marketing/presentation/marketing_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/coupons/presentation/coupon_form_screen.dart';
import '../../features/coupons/presentation/coupons_screen.dart';
import '../../features/courier/presentation/courier_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/flash_sales/presentation/flash_sales_screen.dart';
import '../../features/fraud_security/presentation/fraud_security_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/products/presentation/product_form_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/shortlinks/presentation/shortlinks_screen.dart';
import '../../features/staff/presentation/staff_screen.dart';
import '../widgets/app_shell.dart';

/// Route paths in one place — referenced from screens via `AppRoute.x.path`
/// instead of magic strings.
enum AppRoute {
  login('/login'),
  dashboard('/dashboard'),
  orders('/orders'),
  products('/products'),
  marketing('/marketing'),
  more('/more');

  const AppRoute(this.path);
  final String path;
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouterProvider = Provider<GoRouter>((ref) {
  // Repaint router when auth state changes so redirect runs again.
  final authNotifier = ValueNotifier<AuthSession?>(
    ref.read(authControllerProvider),
  );
  ref
    ..onDispose(authNotifier.dispose)
    ..listen(authControllerProvider, (_, next) => authNotifier.value = next);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoute.dashboard.path,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final loggedIn = ref.read(authControllerProvider) != null;
      final goingToLogin = state.matchedLocation == AppRoute.login.path;

      if (!loggedIn && !goingToLogin) return AppRoute.login.path;
      if (loggedIn && goingToLogin) return AppRoute.dashboard.path;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoute.login.path,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => OrderDetailScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/products/new',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ProductFormScreen(),
      ),
      GoRoute(
        path: '/products/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ProductFormScreen(productId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/customers',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const CustomersScreen(),
      ),
      GoRoute(
        path: '/customers/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            CustomerDetailScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/inventory',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const InventoryScreen(),
      ),
      GoRoute(
        path: '/coupons',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const CouponsScreen(),
      ),
      GoRoute(
        path: '/coupons/new',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const CouponFormScreen(),
      ),
      GoRoute(
        path: '/flash-sales',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const FlashSalesScreen(),
      ),
      GoRoute(
        path: '/shortlinks',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ShortlinksScreen(),
      ),
      GoRoute(
        path: '/analytics',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/courier',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const CourierScreen(),
      ),
      GoRoute(
        path: '/fraud-security',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const FraudSecurityScreen(),
      ),
      GoRoute(
        path: '/staff',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const StaffScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const NotificationsScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoute.dashboard.path,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: AppRoute.orders.path,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: OrdersScreen()),
          ),
          GoRoute(
            path: AppRoute.products.path,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ProductsScreen()),
          ),
          GoRoute(
            path: AppRoute.marketing.path,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: MarketingScreen()),
          ),
          GoRoute(
            path: AppRoute.more.path,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: MoreScreen()),
          ),
        ],
      ),
    ],
  );
});
