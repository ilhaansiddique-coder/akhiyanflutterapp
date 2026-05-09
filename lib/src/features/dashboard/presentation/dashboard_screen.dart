import 'dart:math' as math;

import 'package:akhiyan_admin/api/akhiyan_api.dart';
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_shell.dart';
import 'package:akhiyan_admin/src/core/widgets/date_range_picker_dialog.dart';
import 'package:akhiyan_admin/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const Color _kCardOrange = AppColors.primary;
const Color _kCardYellow = AppColors.warning;
const Color _kCardBlue = Color(0xFF3B82F6);
const Color _kCardRed = AppColors.error;
const Color _kCardTeal = AppColors.secondary;
const Color _kCardIndigo = Color(0xFF6366F1);
const Color _kCardPurple = Color(0xFF8B5CF6);
const Color _kCardGreen = Color(0xFF10B981);

enum _DashboardMetricTab { totalOrders, actualSalesCourier }

extension _DashboardMetricTabCopy on _DashboardMetricTab {
  String get label => switch (this) {
    _DashboardMetricTab.totalOrders => 'Total Orders',
    _DashboardMetricTab.actualSalesCourier => 'Actual Sales & Courier Sent',
  };
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static final DateTime _firstDate = DateTime(2020);

  late DateTimeRange _range;
  var _selectedMetricTab = _DashboardMetricTab.totalOrders;

  @override
  void initState() {
    super.initState();
    _range = _defaultRange();
  }

  static DateTimeRange _defaultRange() {
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    return DateTimeRange(start: yesterday, end: yesterday);
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

  void _resetRange() {
    setState(() => _range = _defaultRange());
  }

  List<_CombinedMetric> _totalOrderCards(DashboardData data) => [
    _CombinedMetric(
      countIcon: Icons.inventory_2_outlined,
      revenueIcon: Icons.attach_money_rounded,
      countLabel: 'Total Orders',
      revenueLabel: 'Total Revenue',
      count: data.stats.totalOrders,
      revenue: data.stats.totalRevenue,
      color: _kCardOrange,
    ),
    _CombinedMetric(
      countIcon: Icons.schedule_rounded,
      revenueIcon: Icons.attach_money_rounded,
      countLabel: 'Pending Orders',
      revenueLabel: 'Pending Revenue',
      count: data.orderCounts.pending,
      revenue: data.revenueByStatus.pending,
      color: _kCardYellow,
    ),
    _CombinedMetric(
      countIcon: Icons.check_circle_outline_rounded,
      revenueIcon: Icons.attach_money_rounded,
      countLabel: 'Confirmed Orders',
      revenueLabel: 'Confirmed Revenue',
      count: data.orderCounts.confirmed,
      revenue: data.revenueByStatus.confirmed,
      color: _kCardBlue,
    ),
    _CombinedMetric(
      countIcon: Icons.cancel_outlined,
      revenueIcon: Icons.attach_money_rounded,
      countLabel: 'Cancelled Orders',
      revenueLabel: 'Cancelled Amount (excl. shipping)',
      count: data.orderCounts.cancelled,
      revenue: data.stats.cancelledRevenue,
      color: _kCardRed,
    ),
  ];

  List<_CombinedMetric> _actualSalesCourierCards(DashboardData data) => [
    _CombinedMetric(
      countIcon: Icons.local_shipping_outlined,
      revenueIcon: Icons.attach_money_rounded,
      countLabel: 'Courier Sent Orders',
      revenueLabel: 'Sales Revenue (excl. shipping)',
      count: data.stats.shippedOrders,
      revenue: data.stats.shippedRevenue,
      color: _kCardTeal,
    ),
    _CombinedMetric(
      countIcon: Icons.today_outlined,
      revenueIcon: Icons.attach_money_rounded,
      countLabel: "Today's Courier",
      revenueLabel: "Today's Sales",
      count: data.stats.todayShipped,
      revenue: data.stats.todayShippedRevenue,
      color: _kCardIndigo,
    ),
    _CombinedMetric(
      countIcon: Icons.people_alt_outlined,
      revenueIcon: Icons.stacked_line_chart_rounded,
      countLabel: 'Customers (Shipped)',
      revenueLabel: 'Avg Order Value',
      count: data.stats.shippedCustomers,
      revenue: data.stats.shippedOrders > 0
          ? data.stats.shippedRevenue / data.stats.shippedOrders
          : 0,
      color: _kCardPurple,
    ),
    _CombinedMetric(
      countIcon: Icons.verified_outlined,
      revenueIcon: Icons.attach_money_rounded,
      countLabel: 'Delivered Orders',
      revenueLabel: 'Delivered Revenue',
      count: data.orderCounts.delivered,
      revenue: data.revenueByStatus.delivered,
      color: _kCardGreen,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(dashboardDataProvider(_range));
    final data = asyncData.value;
    final isInitialLoading = asyncData.isLoading && data == null;
    final isRefreshing = asyncData.isLoading && data != null;
    final errorMessage = asyncData.hasError
        ? _describeError(asyncData.error)
        : null;
    final visibleCards = data == null
        ? const <_CombinedMetric>[]
        : switch (_selectedMetricTab) {
            _DashboardMetricTab.totalOrders => _totalOrderCards(data),
            _DashboardMetricTab.actualSalesCourier => _actualSalesCourierCards(
              data,
            ),
          };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        leading: IconButton(
          onPressed: () => appShellScaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: AppColors.outline),
        ),
        titleSpacing: 0,
        title: Text(
          'Dashboard',
          style: context.h3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onBackground,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(
              Icons.home_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (!context.mounted) return;
              context.go('/login');
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(dashboardDataProvider(_range));
          await ref.read(dashboardDataProvider(_range).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          children: [
            _DashboardFilterCard(
              range: _range,
              firstDate: _firstDate,
              busy: isRefreshing || isInitialLoading,
              onTap: _pickRange,
              onReset: _resetRange,
            ),
            const SizedBox(height: AppSpacing.md),
            _DashboardMetricTabs(
              selected: _selectedMetricTab,
              onChanged: (tab) => setState(() => _selectedMetricTab = tab),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isInitialLoading) const _DashboardSkeleton(),
            if (!isInitialLoading && data == null && errorMessage != null)
              _DashboardErrorCard(
                message: errorMessage,
                onRetry: () => ref.invalidate(dashboardDataProvider(_range)),
              ),
            if (!isInitialLoading && data != null) ...[
              if (errorMessage != null) ...[
                _DashboardErrorCard(
                  message: errorMessage,
                  onRetry: () => ref.invalidate(dashboardDataProvider(_range)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _CombinedStatsGrid(
                  key: ValueKey(_selectedMetricTab),
                  cards: visibleCards,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _OrdersChartCard(points: data.dailyOrders),
              const SizedBox(height: AppSpacing.md),
              _StatusDonutCard(orderCounts: data.orderCounts),
              const SizedBox(height: AppSpacing.md),
              _TableSection(
                title: 'Recent Orders',
                child: _RecentOrdersTable(orders: data.recentOrders),
              ),
              const SizedBox(height: AppSpacing.md),
              _TableSection(
                title: 'Top Selling Products',
                child: _TopProductsTable(products: data.topProducts),
              ),
              const SizedBox(height: AppSpacing.md),
              if (data.lowStock.isNotEmpty)
                _LowStockAlertCard(items: data.lowStock),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardMetricTabs extends StatelessWidget {
  const _DashboardMetricTabs({required this.selected, required this.onChanged});

  final _DashboardMetricTab selected;
  final ValueChanged<_DashboardMetricTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _DashboardMetricTabButton(
              label: _DashboardMetricTab.totalOrders.label,
              selected: selected == _DashboardMetricTab.totalOrders,
              onTap: () => onChanged(_DashboardMetricTab.totalOrders),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _DashboardMetricTabButton(
              label: _DashboardMetricTab.actualSalesCourier.label,
              selected: selected == _DashboardMetricTab.actualSalesCourier,
              onTap: () => onChanged(_DashboardMetricTab.actualSalesCourier),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricTabButton extends StatelessWidget {
  const _DashboardMetricTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.bodySm.copyWith(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardFilterCard extends StatelessWidget {
  const _DashboardFilterCard({
    required this.range,
    required this.firstDate,
    required this.busy,
    required this.onTap,
    required this.onReset,
  });

  final DateTimeRange range;
  final DateTime firstDate;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final label = dateRangePresetLabel(range, firstDate: firstDate);
    return _SurfaceCard(
      borderColor: AppColors.outlineVariant,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Filter by Date',
                style: context.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                label,
                                style: context.bodySm.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDarker,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s12),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : GestureDetector(
                          onTap: onReset,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(
                                color: AppColors.outlineVariant,
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                          ),
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

class _CombinedMetric {
  const _CombinedMetric({
    required this.countIcon,
    required this.revenueIcon,
    required this.countLabel,
    required this.revenueLabel,
    required this.count,
    required this.revenue,
    required this.color,
  });

  final IconData countIcon;
  final IconData revenueIcon;
  final String countLabel;
  final String revenueLabel;
  final int count;
  final double revenue;
  final Color color;
}

class _CombinedStatsGrid extends StatelessWidget {
  const _CombinedStatsGrid({required this.cards, super.key});

  final List<_CombinedMetric> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _CombinedMetricCard(metric: cards[i])),
                if (i + 1 < cards.length) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _CombinedMetricCard(metric: cards[i + 1])),
                ] else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
          if (i + 2 < cards.length) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _CombinedMetricCard extends StatelessWidget {
  const _CombinedMetricCard({required this.metric});

  final _CombinedMetric metric;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      borderColor: metric.color.withValues(alpha: 0.35),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _MetricRow(
            icon: metric.countIcon,
            label: metric.countLabel,
            value: _formatCount(metric.count),
            color: metric.color,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Divider(
              height: 1,
              color: AppColors.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          _MetricRow(
            icon: metric.revenueIcon,
            label: metric.revenueLabel,
            value: _formatCurrency(metric.revenue),
            color: metric.color.withValues(alpha: 0.88),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.dataDisplay.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: context.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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

class _OrdersChartCard extends StatelessWidget {
  const _OrdersChartCard({required this.points});

  final List<DailyOrderPoint> points;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 7 Days Orders',
            style: context.h3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 220,
            child: points.isEmpty
                ? const _EmptyStateText(
                    message: 'No order data for the last 7 days.',
                  )
                : CustomPaint(
                    size: Size.infinite,
                    painter: _OrdersBarChartPainter(points: points),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrdersBarChartPainter extends CustomPainter {
  _OrdersBarChartPainter({required this.points});

  final List<DailyOrderPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const topGutter = 10.0;
    const leftGutter = 18.0;
    const bottomGutter = 28.0;
    final chartRect = Rect.fromLTWH(
      leftGutter,
      topGutter,
      size.width - leftGutter,
      size.height - topGutter - bottomGutter,
    );

    final maxCount = points.fold<int>(
      0,
      (max, point) => point.count > max ? point.count : max,
    );
    final scale = math.max(1, maxCount).toDouble();
    final slotWidth = chartRect.width / points.length;
    const barRatio = 0.56;

    final barPaint = Paint()..color = AppColors.primary;
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    final axisStyle = AppTypography.caption.copyWith(
      fontSize: 10,
      color: AppColors.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    final valueStyle = AppTypography.caption.copyWith(
      fontSize: 10,
      color: AppColors.onBackground,
      fontWeight: FontWeight.w800,
    );

    for (var tick = 0; tick <= 4; tick++) {
      final pct = tick / 4;
      final y = chartRect.bottom - chartRect.height * pct;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      final label = (scale * pct).round().toString();
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final barHeight = chartRect.height * (point.count / scale);
      final left =
          chartRect.left + (slotWidth * i) + slotWidth * (1 - barRatio) / 2;
      final width = slotWidth * barRatio;
      final top = chartRect.bottom - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, barHeight < 3 ? 3 : barHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, barPaint);

      if (point.count > 0) {
        final countPainter = TextPainter(
          text: TextSpan(text: '${point.count}', style: valueStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        countPainter.paint(
          canvas,
          Offset(left + width / 2 - countPainter.width / 2, top - 16),
        );
      }

      final labelPainter = TextPainter(
        text: TextSpan(text: point.date, style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotWidth);
      labelPainter.paint(
        canvas,
        Offset(left + width / 2 - labelPainter.width / 2, chartRect.bottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrdersBarChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _StatusDonutCard extends StatelessWidget {
  const _StatusDonutCard({required this.orderCounts});

  final DashboardOrderCounts orderCounts;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, int>>[
      MapEntry('Pending', orderCounts.pending),
      MapEntry('Confirmed', orderCounts.confirmed),
      MapEntry('Processing', orderCounts.processing),
      MapEntry('Courier Sent', orderCounts.shipped),
      MapEntry('Delivered', orderCounts.delivered),
      MapEntry('Cancelled', orderCounts.cancelled),
    ].where((entry) => entry.value > 0).toList();

    final colors = <Color>[
      _kCardYellow,
      _kCardBlue,
      _kCardIndigo,
      _kCardPurple,
      _kCardGreen,
      _kCardRed,
    ];

    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    return _SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Status Breakdown',
            style: context.h3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (entries.isEmpty)
            const SizedBox(
              height: 220,
              child: _EmptyStateText(
                message: 'No orders in the selected window.',
              ),
            )
          else ...[
            SizedBox(
              height: 190,
              child: Center(
                child: SizedBox(
                  width: 170,
                  height: 170,
                  child: CustomPaint(
                    painter: _StatusDonutPainter(
                      values: entries.map((entry) => entry.value).toList(),
                      colors: colors.take(entries.length).toList(),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: AppTypography.dataDisplay.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onBackground,
                            ),
                          ),
                          Text(
                            'orders',
                            style: context.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < entries.length; i++)
                  _StatusLegendChip(
                    color: colors[i],
                    label: entries[i].key,
                    count: entries[i].value,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusDonutPainter extends CustomPainter {
  _StatusDonutPainter({required this.values, required this.colors});

  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total <= 0) return;

    final strokeWidth = size.width * 0.18;
    final rect = Offset.zero & size;
    final arcRect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      rect.width - strokeWidth,
      rect.height - strokeWidth,
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = AppColors.borderSubtle;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);

    var startAngle = -math.pi / 2;
    final slicePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = strokeWidth;

    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2;
      slicePaint.color = colors[i];
      canvas.drawArc(arcRect, startAngle, sweep, false, slicePaint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _StatusDonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _StatusLegendChip extends StatelessWidget {
  const _StatusLegendChip({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label • $count',
            style: context.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.onBackground,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableSection extends StatelessWidget {
  const _TableSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.h3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _RecentOrdersTable extends StatelessWidget {
  const _RecentOrdersTable({required this.orders});

  final List<OrderListItem> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyStateText(message: 'No recent orders found.');
    }

    final displayed = orders.take(8).toList();
    return Column(
      children: [
        const _TableHeaderRow(
          cells: ['#', 'Customer', 'Total', 'Status'],
          flex: [1, 3, 2, 2],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < displayed.length; i++) ...[
          _RecentOrderRow(item: displayed[i]),
          if (i < displayed.length - 1)
            const Divider(height: AppSpacing.md, color: AppColors.borderSubtle),
        ],
      ],
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  const _RecentOrderRow({required this.item});

  final OrderListItem item;

  @override
  Widget build(BuildContext context) {
    final statusMeta = _statusMeta(item.status);
    return InkWell(
      onTap: () => context.push('/orders/${item.id}'),
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '#${item.id}',
                style: context.caption.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                item.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onBackground,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatCurrency(item.total),
                textAlign: TextAlign.right,
                style: AppTypography.dataDisplay.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusMeta.background,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    statusMeta.label,
                    style: context.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusMeta.foreground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductsTable extends StatelessWidget {
  const _TopProductsTable({required this.products});

  final List<TopProductSummary> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _EmptyStateText(message: 'No top-selling products yet.');
    }

    final displayed = products.take(8).toList();
    return Column(
      children: [
        const _TableHeaderRow(
          cells: ['Products', 'Sales', 'Total'],
          flex: [4, 1, 2],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < displayed.length; i++) ...[
          _TopProductRow(item: displayed[i]),
          if (i < displayed.length - 1)
            const Divider(height: AppSpacing.md, color: AppColors.borderSubtle),
        ],
      ],
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.item});

  final TopProductSummary item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.onBackground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${item.soldCount}',
              textAlign: TextAlign.center,
              style: context.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatCurrency(item.estimatedRevenue),
              textAlign: TextAlign.right,
              style: AppTypography.dataDisplay.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockAlertCard extends StatelessWidget {
  const _LowStockAlertCard({required this.items});

  final List<DashboardLowStockItem> items;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      borderColor: AppColors.errorContainer,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Low Stock Alert',
                style: context.h3.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _LowStockRow(item: items[i]),
                if (i < items.length - 1) const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.item});

  final DashboardLowStockItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.errorContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.error,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: context.bodySm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                if (item.hasVariants)
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final variant in item.variants)
                        _LowStockVariantChip(variant: variant),
                    ],
                  )
                else
                  Text(
                    'Stock: ${item.stock}',
                    style: context.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
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

class _LowStockVariantChip extends StatelessWidget {
  const _LowStockVariantChip({required this.variant});

  final DashboardLowStockVariant variant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        '${variant.label}: ${variant.stock}',
        style: context.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.onErrorContainer,
        ),
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({required this.cells, required this.flex});

  final List<String> cells;
  final List<int> flex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(
            flex: flex[i],
            child: Text(
              cells[i],
              textAlign: i >= cells.length - 2
                  ? TextAlign.right
                  : TextAlign.left,
              style: context.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SkeletonCombinedGrid(),
        SizedBox(height: AppSpacing.lg),
        _SkeletonChartCard(),
        SizedBox(height: AppSpacing.md),
        _SkeletonChartCard(),
        SizedBox(height: AppSpacing.md),
        _SkeletonTableCard(),
        SizedBox(height: AppSpacing.md),
        _SkeletonTableCard(),
      ],
    );
  }
}

class _SkeletonCombinedGrid extends StatelessWidget {
  const _SkeletonCombinedGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: _SkeletonCombinedCard()),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _SkeletonCombinedCard()),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: _SkeletonCombinedCard()),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _SkeletonCombinedCard()),
          ],
        ),
      ],
    );
  }
}

class _SkeletonCombinedCard extends StatelessWidget {
  const _SkeletonCombinedCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      borderColor: AppColors.outlineVariant,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SkeletonMetricRow(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.borderSubtle),
          ),
          _SkeletonMetricRow(),
        ],
      ),
    );
  }
}

class _SkeletonMetricRow extends StatelessWidget {
  const _SkeletonMetricRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _SkeletonBox(width: 34, height: 34, radius: AppRadius.medium),
          SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 72, height: 18, radius: AppRadius.small),
                SizedBox(height: 6),
                _SkeletonBox(width: 140, height: 10, radius: AppRadius.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonChartCard extends StatelessWidget {
  const _SkeletonChartCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: 160, height: 16, radius: AppRadius.small),
          SizedBox(height: AppSpacing.md),
          _SkeletonBox(
            width: double.infinity,
            height: 220,
            radius: AppRadius.large,
          ),
        ],
      ),
    );
  }
}

class _SkeletonTableCard extends StatelessWidget {
  const _SkeletonTableCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: 150, height: 16, radius: AppRadius.small),
          SizedBox(height: AppSpacing.md),
          _SkeletonBox(
            width: double.infinity,
            height: 14,
            radius: AppRadius.small,
          ),
          SizedBox(height: AppSpacing.sm),
          _SkeletonBox(
            width: double.infinity,
            height: 14,
            radius: AppRadius.small,
          ),
          SizedBox(height: AppSpacing.sm),
          _SkeletonBox(
            width: double.infinity,
            height: 14,
            radius: AppRadius.small,
          ),
          SizedBox(height: AppSpacing.sm),
          _SkeletonBox(
            width: double.infinity,
            height: 14,
            radius: AppRadius.small,
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _DashboardErrorCard extends StatelessWidget {
  const _DashboardErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      borderColor: AppColors.errorContainer,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.error),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              message,
              style: context.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: context.bodySm.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    required this.padding,
    this.borderColor = AppColors.slateBorder,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _EmptyStateText extends StatelessWidget {
  const _EmptyStateText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: context.bodySm.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusVisual {
  const _StatusVisual({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

_StatusVisual _statusMeta(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return const _StatusVisual(
        label: 'Confirmed',
        background: Color(0xFFDBEAFE),
        foreground: Color(0xFF1D4ED8),
      );
    case 'processing':
      return const _StatusVisual(
        label: 'Processing',
        background: Color(0xFFE0E7FF),
        foreground: Color(0xFF4338CA),
      );
    case 'shipped':
      return const _StatusVisual(
        label: 'Courier Sent',
        background: Color(0xFFEDE9FE),
        foreground: Color(0xFF7C3AED),
      );
    case 'delivered':
      return const _StatusVisual(
        label: 'Delivered',
        background: Color(0xFFD1FAE5),
        foreground: Color(0xFF047857),
      );
    case 'cancelled':
    case 'canceled':
      return const _StatusVisual(
        label: 'Cancelled',
        background: Color(0xFFFEE2E2),
        foreground: Color(0xFFB91C1C),
      );
    default:
      return const _StatusVisual(
        label: 'Pending',
        background: Color(0xFFFEF3C7),
        foreground: Color(0xFFB45309),
      );
  }
}

String _describeError(Object? error) {
  if (error is ApiException) return error.message;
  if (error is NetworkException) return 'No internet connection';
  return 'Could not load dashboard';
}

String _formatCount(num value) {
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}

String _formatCurrency(num value) => '৳${_formatTaka(value)}';

String _formatTaka(num value) {
  final s = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}
