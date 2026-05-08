import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../api/akhiyan_api.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shell_app_bar.dart';
import '../../../core/widgets/date_range_picker_dialog.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

/// Dashboard home — bound to live data via [dashboardDataProvider].
/// Hardcoded numbers were replaced with reactive bindings; while data is
/// loading the cells fall back to `—`. Pull-to-refresh re-invokes the
/// provider; errors render as a banner with a retry button.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Earliest selectable date — kept in sync between the picker (firstDate)
  // and the pill's preset detection (so "All Time" resolves consistently).
  static final DateTime _firstDate = DateTime(2020);

  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    // Default to today; the user can switch to other presets from the pill.
    // IMPORTANT: emit a real 24h window, not a zero-width range. Sending
    // `start == end` to /dashboard makes the backend treat the slice as 0
    // seconds wide, which historically returned 500 instead of empty stats.
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    _range = DateTimeRange(start: start, end: end);
  }

  Future<void> _pickRange() async {
    final picked = await showAdvancedDateRangePicker(
      context,
      initialRange: _range,
      firstDate: _firstDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _range = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final session = ref.watch(authControllerProvider);
    final firstName = session?.name.split(' ').first ?? 'there';

    final asyncData = ref.watch(dashboardDataProvider(_range));
    final data = asyncData.value;
    final isLoading = asyncData.isLoading;
    final errorMessage = asyncData.hasError ? _describeError(asyncData.error) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppShellAppBar(),
      // FAB lives on the shell now (centered + button in the bottom nav).
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardDataProvider(_range));
          await ref.read(dashboardDataProvider(_range).future);
        },
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          children: [
            // Pill MUST stay top-right of the greeting at every width — do
            // not switch this back to a Wrap or stack vertically on narrow
            // screens. The greeting uses Expanded so its long text and date
            // line wrap inside the available space, and the pill keeps its
            // natural width on the right.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Greeting(name: firstName)),
                const SizedBox(width: AppSpacing.sm),
                _DateRangePill(
                  range: _range,
                  firstDate: _firstDate,
                  onTap: _pickRange,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Error state — only shows on outright failure.
            if (errorMessage != null) ...[
              _ErrorBanner(
                message: errorMessage,
                onRetry: () => ref.invalidate(dashboardDataProvider(_range)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Conditional fraud banner — only when count > 0.
            if ((data?.flaggedOrdersCount ?? 0) > 0) ...[
              _FraudBanner(count: data!.flaggedOrdersCount),
              const SizedBox(height: AppSpacing.lg),
            ],
            _StatsGrid(cards: data?.cards),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Recent Orders',
              trailing: TextButton(
                onPressed: () => context.go('/orders'),
                child: const Text('View All'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RecentOrdersCard(orders: data?.recentOrders, isLoading: isLoading),
            const SizedBox(height: 16),
            const _SectionHeader(title: 'Top Products'),
            const SizedBox(height: AppSpacing.md),
            _TopProducts(products: data?.topProducts, isLoading: isLoading),
          ],
        ),
      ),
    );
  }
}

// ─── Date range pill ──────────────────────────────────────────────────────

/// Compact pill that shows the matching preset name (or "Custom") for the
/// active [range]. Width auto-fits the label so it sits to the left under
/// the greeting like Stripe / Shopify admin filters.
class _DateRangePill extends StatelessWidget {
  const _DateRangePill({
    required this.range,
    required this.firstDate,
    required this.onTap,
  });

  final DateTimeRange range;
  final DateTime firstDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = dateRangePresetLabel(range, firstDate: firstDate);
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more,
                    size: 18, color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────

String _describeError(Object? e) {
  if (e is ApiException) return e.message;
  if (e is NetworkException) return 'No internet connection';
  return 'Could not load dashboard';
}

String _formatDelta(int? pct) {
  if (pct == null) return '';
  return '${pct >= 0 ? '+' : ''}$pct%';
}

String _formatCompact(num? n) {
  if (n == null) return '—';
  if (n >= 1000000) return '৳${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '৳${(n / 1000).toStringAsFixed(1)}k';
  return '৳${n.toStringAsFixed(0)}';
}

String _formatCount(num? n) {
  if (n == null) return '—';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toStringAsFixed(0);
}

String _formatTaka(num n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _formatOrderId(String id) {
  final n = int.tryParse(id);
  if (n != null) return '#AK-${n.toString().padLeft(4, '0')}';
  return '#${id.length > 8 ? id.substring(0, 8) : id}';
}

_OrderStatus _parseStatus(String s) {
  switch (s.toLowerCase()) {
    case 'pending':
      return _OrderStatus.pending;
    case 'confirmed':
      return _OrderStatus.confirmed;
    case 'processing':
      return _OrderStatus.processing;
    case 'shipped':
      return _OrderStatus.shipped;
    case 'delivered':
      return _OrderStatus.delivered;
    case 'cancelled':
    case 'canceled':
      return _OrderStatus.cancelled;
    default:
      return _OrderStatus.pending;
  }
}

// ─── Greeting ─────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning, $name',
          style: AppTypography.h1.copyWith(
            fontSize: 22,
            height: 1.2,
            color: AppColors.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          today,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: AppColors.error, size: 20),
            const SizedBox(width: AppSpacing.md - 4),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onErrorContainer,
                textStyle: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fraud / suspicious orders banner (conditional) ───────────────────────

class _FraudBanner extends StatelessWidget {
  const _FraudBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        onTap: () => context.push('/fraud-security'),
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.priority_high,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '$count suspicious order${count == 1 ? '' : 's'} flagged — Review now',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.onErrorContainer,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stats grid ───────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.cards});
  final DashboardCards? cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 85,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          return SizedBox(
            width: 150,
            child: switch (index) {
              0 => _DashStat(
                label: "TODAY'S ORDERS",
                value: _formatCount(cards?.todayOrders.value),
                trend: _formatDelta(cards?.todayOrders.deltaPct),
              ),
              1 => _DashStat(
                label: "TODAY'S REVENUE",
                value: _formatCompact(cards?.todayRevenue.value),
                trend: _formatDelta(cards?.todayRevenue.deltaPct),
              ),
              2 => _DashStat(
                label: 'PENDING ORDERS',
                value: cards == null ? '—' : cards!.pendingOrders.value.toStringAsFixed(0),
                valueColor: AppColors.warning,
                trailingIcon: Icons.access_time_rounded,
                trailingColor: AppColors.warning,
              ),
              _ => _DashStat(
                label: 'LOW STOCK',
                value: cards == null
                    ? '—'
                    : cards!.lowStockItems.value.toStringAsFixed(0).padLeft(2, '0'),
                valueColor: AppColors.error,
                trailingIcon: Icons.shopping_bag_outlined,
                trailingColor: AppColors.error,
              ),
            },
          );
        },
      ),
    );
  }
}

class _DashStat extends StatelessWidget {
  const _DashStat({
    required this.label,
    required this.value,
    this.trend,
    this.valueColor,
    this.trailingIcon,
    this.trailingColor,
  });

  final String label;
  final String value;
  final String? trend;
  final Color? valueColor;
  final IconData? trailingIcon;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final hasTrend = trend != null && trend!.isNotEmpty;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0.8,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppTypography.dataDisplayLg.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? AppColors.onBackground,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (hasTrend)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    trend!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onSuccessContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    ),
                  ),
                ),
              if (trailingIcon != null)
                Icon(trailingIcon, size: 14, color: trailingColor),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.h3.copyWith(
            fontSize: 18,
            color: AppColors.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ─── Recent Orders ────────────────────────────────────────────────────────

class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({required this.orders, required this.isLoading});
  final List<OrderListItem>? orders;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (orders == null && isLoading) {
      return AppCard(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: List.generate(
            5,
            (i) => Column(
              children: [
                const _OrderRowSkeleton(),
                if (i < 4) const Divider(height: 1, color: AppColors.borderSubtle),
              ],
            ),
          ),
        ),
      );
    }
    if (orders == null || orders!.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'No recent orders',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final displayed = orders!.take(5).toList();
    return AppCard(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < displayed.length; i++) ...[
            _OrderRow(item: displayed[i]),
            if (i < displayed.length - 1)
              const Divider(height: 1, color: AppColors.borderSubtle),
          ],
        ],
      ),
    );
  }
}

enum _OrderStatus { pending, confirmed, processing, shipped, delivered, cancelled }

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.item});
  final OrderListItem item;

  ({Color bg, Color fg, String label}) _statusMeta(_OrderStatus status) {
    switch (status) {
      case _OrderStatus.pending:
        return (
          bg: AppColors.warningContainer,
          fg: AppColors.onWarningContainer,
          label: 'Pending',
        );
      case _OrderStatus.confirmed:
        return (
          bg: AppColors.infoContainer,
          fg: AppColors.onInfoContainer,
          label: 'Confirmed',
        );
      case _OrderStatus.processing:
        return (
          bg: AppColors.primaryContainer,
          fg: AppColors.onPrimaryContainer,
          label: 'Processing',
        );
      case _OrderStatus.shipped:
        return (
          bg: AppColors.infoContainer,
          fg: AppColors.onInfoContainer,
          label: 'Shipped',
        );
      case _OrderStatus.delivered:
        return (
          bg: AppColors.successContainer,
          fg: AppColors.onSuccessContainer,
          label: 'Delivered',
        );
      case _OrderStatus.cancelled:
        return (
          bg: AppColors.errorContainer,
          fg: AppColors.onErrorContainer,
          label: 'Cancelled',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _formatOrderId(item.id);
    final amount = '৳${_formatTaka(item.total)}';
    final m = _statusMeta(_parseStatus(item.status));
    return InkWell(
      onTap: () => context.push('/orders/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id,
                    style: AppTypography.dataDisplay.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onBackground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.customerName,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: AppTypography.dataDisplay.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: m.bg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    m.label,
                    style: AppTypography.caption.copyWith(
                      color: m.fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderRowSkeleton extends StatelessWidget {
  const _OrderRowSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
          ),
        );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(80, 12),
                const SizedBox(height: 6),
                bar(120, 10),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              bar(60, 12),
              const SizedBox(height: 6),
              bar(70, 14),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Top Products ─────────────────────────────────────────────────────────

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.products, required this.isLoading});
  final List<TopProductSummary>? products;
  final bool isLoading;

  // Used as fallback gradients when image fails / network unreachable.
  static const _fallbackGradients = <List<Color>>[
    [Color(0xFF1F1F1F), Color(0xFFB1262C)],
    [Color(0xFFD7C3A6), Color(0xFFA68A6F)],
    [Color(0xFF2D2D2D), Color(0xFF6B6B6B)],
    [Color(0xFF111827), Color(0xFF374151)],
  ];

  @override
  Widget build(BuildContext context) {
    if (products == null && isLoading) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.78,
        children: List.generate(4, (_) => const _ProductCardSkeleton()),
      );
    }

    if (products == null || products!.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'No products yet',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      // 0.78 keeps the image area dominant while leaving room for two
      // text rows below — tweaked visually so cards feel uniform without
      // images being squished on narrow screens.
      childAspectRatio: 0.78,
      children: [
        for (var i = 0; i < products!.length; i++)
          _ProductCard(
            name: products![i].name,
            unitsSold: products![i].soldCount,
            imageUrl: products![i].image,
            fallbackGradient:
                _fallbackGradients[i % _fallbackGradients.length],
          ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.unitsSold,
    required this.imageUrl,
    required this.fallbackGradient,
  });
  final String name;
  final int unitsSold;
  final String imageUrl;
  final List<Color> fallbackGradient;

  @override
  Widget build(BuildContext context) {
    // Custom container instead of AppCard so we get rounded image
    // clipping AND a softer drop shadow that matches the rest of the
    // app's elevated surfaces (Users cards, search bar, etc.).
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        border: Border.all(color: AppColors.slateBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return _gradientPlaceholder();
              },
              errorBuilder: (_, _, _) => _gradientPlaceholder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onBackground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$unitsSold units sold',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fallbackGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        border: Border.all(color: AppColors.slateBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(color: AppColors.surfaceContainerHigh),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 70,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
