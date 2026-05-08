import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/marketing/presentation/marketing_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/courier/presentation/courier_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/fraud_security/presentation/fraud_security_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/order_form_screen.dart';
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
  marketing('/marketing');

  const AppRoute(this.path);
  final String path;
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouterProvider = Provider<GoRouter>((ref) {
  // Repaint router when auth state changes so redirect runs again.
  final authNotifier = ValueNotifier<User?>(
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
      // Login is the only route OUTSIDE the shell — there's no bottom nav
      // before the user is authenticated.
      GoRoute(
        path: AppRoute.login.path,
        builder: (_, _) => const LoginScreen(),
      ),
      // Every other screen lives inside the shell so the bottom nav and
      // notification bell are present everywhere.
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
            path: '/orders/new',
            builder: (_, _) => const OrderFormScreen(),
          ),
          GoRoute(
            path: '/orders/:id',
            builder: (_, state) =>
                OrderDetailScreen(orderId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoute.products.path,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ProductsScreen()),
          ),
          GoRoute(
            path: '/products/new',
            builder: (_, _) => const ProductFormScreen(),
          ),
          GoRoute(
            path: '/products/:id',
            builder: (_, state) =>
                ProductFormScreen(productId: state.pathParameters['id']),
          ),
          GoRoute(
            path: AppRoute.marketing.path,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: MarketingScreen()),
          ),
          GoRoute(
            path: '/customers',
            builder: (_, _) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/customers/:id',
            builder: (_, state) => CustomerDetailScreen(
              customerId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/inventory',
            builder: (_, _) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/shortlinks',
            builder: (_, _) => const ShortlinksScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (_, _) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/courier',
            builder: (_, _) => const CourierScreen(),
          ),
          GoRoute(
            path: '/fraud-security',
            builder: (_, _) => const FraudSecurityScreen(),
          ),
          GoRoute(
            path: '/staff',
            builder: (_, _) => const StaffScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
  );
});
