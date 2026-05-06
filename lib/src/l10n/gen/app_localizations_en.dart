// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Akhiyan Admin';

  @override
  String get appTagline => 'Store Management';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navOrders => 'Orders';

  @override
  String get navProducts => 'Products';

  @override
  String get navMarketing => 'Marketing';

  @override
  String get navMore => 'More';

  @override
  String get loginTitle => 'Akhiyan Admin';

  @override
  String get loginSubtitle => 'Store Management';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginEmailHint => 'admin@akhiyan.com';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordHint => '••••••••';

  @override
  String get loginSubmit => 'Login';

  @override
  String get loginForgot => 'Forgot Password?';

  @override
  String get loginTrustedBy => 'Trusted by global commerce leaders';

  @override
  String dashboardGreetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String get dashboardSubtitle =>
      'Here\'s what\'s happening with your store today.';

  @override
  String get statTodaysOrders => 'Today\'s Orders';

  @override
  String get statTodaysRevenue => 'Today\'s Revenue';

  @override
  String get statPendingOrders => 'Pending Orders';

  @override
  String get statLowStock => 'Low Stock Items';

  @override
  String get actionNewProduct => 'New Product';

  @override
  String get actionUpdateStock => 'Update Stock';

  @override
  String get actionLaunchCampaign => 'Launch Campaign';

  @override
  String get actionExportReport => 'Export Report';

  @override
  String get sectionRecentOrders => 'Recent Orders';

  @override
  String get sectionTopProducts => 'Top Products';

  @override
  String get viewAll => 'View All';

  @override
  String get analyzeInventory => 'Analyze Inventory';

  @override
  String comingSoon(String feature) {
    return '$feature — coming soon';
  }
}
