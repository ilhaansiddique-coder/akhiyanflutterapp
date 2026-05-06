import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';

/// Number of pending orders awaiting attention. Drives the unread dot on the
/// Orders tab in the bottom nav. Derived from the live orders list — returns
/// 0 while the first page is still loading or on error so the badge degrades
/// gracefully.
final pendingOrdersCountProvider = Provider<int>((ref) {
  final state = ref.watch(ordersListProvider);
  if (state.loading && state.items.isEmpty) return 0;
  return state.items
      .where((o) => o.status.toLowerCase() == 'pending')
      .length;
});
