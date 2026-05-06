import '../../../api/akhiyan_api.dart';

/// Mock implementation for design/UI work without a backend.
class MockAkhiyanApi extends AkhiyanApi {
  late _MockAuthApi _mockAuth;
  late _MockDashboardApi _mockDashboard;

  MockAkhiyanApi()
      : super(
          baseUrl: 'http://mock',
          storage: MockTokenStorage(),
        ) {
    // Initialize mock wrappers that intercept calls to auth & dashboard
    _mockAuth = _MockAuthApi(this);
    _mockDashboard = _MockDashboardApi(this);
  }

  /// Override the auth getter to return the mock implementation
  @override
  AuthApi get auth => _mockAuth;

  /// Override the dashboard getter to return the mock implementation
  @override
  DashboardApi get dashboard => _mockDashboard;
}

class MockTokenStorage implements TokenStorage {
  String? _accessToken;
  String? _refreshToken;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}

class _MockAuthApi extends AuthApi {
  final AkhiyanApi _api;

  _MockAuthApi(this._api) : super(_api);

  @override
  Future<AdminUser> login(String email, String password) async {
    // Instant login without network call
    await Future.delayed(const Duration(milliseconds: 800));
    final user = AdminUser(
      id: 1,
      name: 'Demo Admin',
      email: email,
      phone: '+8801700000000',
      role: 'admin',
      avatar: null,
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
    );
    await _api.storage.save(
      accessToken: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock_refresh',
    );
    return user;
  }

  @override
  Future<AdminUser> me() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return AdminUser(
      id: 1,
      name: 'Demo Admin',
      email: 'admin@akhiyan.com',
      phone: '+8801700000000',
      role: 'admin',
      avatar: null,
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
    );
  }

  @override
  Future<void> logout() async {
    await _api.storage.clear();
  }
}

class _MockDashboardApi extends DashboardApi {
  _MockDashboardApi(super.api);

  @override
  Future<DashboardData> fetch() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return DashboardData(
      cards: DashboardCards(
        todayOrders: StatCard(value: 42, deltaPct: 15),
        todayRevenue: StatCard(value: 25050.75, deltaPct: 8),
        pendingOrders: StatCard(value: 12, deltaPct: -5),
        lowStockItems: StatCard(value: 3, deltaPct: 2),
      ),
      flaggedOrdersCount: 2,
      recentOrders: [
        OrderListItem(
          id: 1,
          customerName: 'Ahmed Hassan',
          customerPhone: '+8801700000001',
          total: 5000.0,
          status: 'processing',
          paymentMethod: 'cod',
          itemCount: 3,
          flagged: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        OrderListItem(
          id: 2,
          customerName: 'Fatima Khan',
          customerPhone: '+8801700000002',
          total: 12500.0,
          status: 'pending',
          paymentMethod: 'bkash',
          itemCount: 5,
          flagged: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ],
      topProducts: [
        TopProductSummary(
          id: 1,
          name: 'Premium White T-Shirt',
          slug: 'premium-white-tshirt',
          image: '',
          soldCount: 342,
          price: 899.0,
        ),
        TopProductSummary(
          id: 2,
          name: 'Black Jeans Classic',
          slug: 'black-jeans-classic',
          image: '',
          soldCount: 287,
          price: 2499.0,
        ),
      ],
    );
  }
}
