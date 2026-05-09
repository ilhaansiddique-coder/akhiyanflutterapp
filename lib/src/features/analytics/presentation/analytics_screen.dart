import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/errors/error_mapper.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/coming_soon.dart';
import 'package:akhiyan_admin/src/core/widgets/notification_bell.dart';
import 'package:akhiyan_admin/src/core/widgets/stat_card.dart';
import 'package:akhiyan_admin/src/core/widgets/states/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAnalytics = ref.watch(analyticsDataProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ),
        title: const Text('Analytics'),
        actions: [
          const NotificationBell(),
          IconButton(
            onPressed: () => ref.invalidate(analyticsDataProvider),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: asyncAnalytics.when(
        loading: () => const LoadingView(),
        error: (e, _) => (e is api.ApiException && e.isNotFound)
            ? comingSoonBody('Analytics')
            : ErrorView(
                message: describeError(e, fallback: 'Could not load analytics'),
                icon: Icons.cloud_off,
                onRetry: () => ref.invalidate(analyticsDataProvider),
              ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(analyticsDataProvider);
            await ref.read(analyticsDataProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  for (final r in const ['7d', '30d', '90d', '1y'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(r.toUpperCase()),
                        selected: r == data.period.toLowerCase(),
                        onSelected: (_) {},
                        selectedColor: AppColors.primaryContainer,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.35,
                children: [
                  StatCard(
                    icon: Icons.payments_outlined,
                    label: 'Revenue',
                    value: _formatCompact(data.stats.revenue),
                  ),
                  StatCard(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Orders',
                    value: data.stats.orders.toString(),
                  ),
                  StatCard(
                    icon: Icons.trending_up,
                    label: 'Avg Order Value',
                    value: _formatCompact(data.stats.avgOrderValue),
                  ),
                  StatCard(
                    icon: Icons.refresh,
                    label: 'Return Rate',
                    value:
                        '${(data.stats.returnRate * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _ChartCard(points: data.revenueChart),
              const SizedBox(height: AppSpacing.lg),
              Text('Top Products',
                  style: AppTypography.h3.copyWith(fontSize: 18)),
              const SizedBox(height: AppSpacing.sm),
              if (data.topProducts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Text(
                      'No sales data yet',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      for (final tp in _withRatios(data.topProducts))
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      tp.product.name,
                                      style: AppTypography.bodyMd.copyWith(
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _formatCompact(tp.product.revenue),
                                    style: AppTypography.bodyMd.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                child: LinearProgressIndicator(
                                  value: tp.ratio,
                                  minHeight: 6,
                                  backgroundColor:
                                      AppColors.surfaceContainer,
                                  valueColor:
                                      const AlwaysStoppedAnimation(
                                          AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatCompact(num n) {
  if (n >= 1000000) return '৳${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '৳${(n / 1000).toStringAsFixed(1)}K';
  return '৳${n.toStringAsFixed(0)}';
}

class _RankedProduct {
  const _RankedProduct(this.product, this.ratio);
  final api.TopProductAnalytics product;
  final double ratio;
}

List<_RankedProduct> _withRatios(List<api.TopProductAnalytics> items) {
  if (items.isEmpty) return const [];
  final max = items
      .map((e) => e.revenue)
      .fold<double>(0, (a, b) => b > a ? b : a);
  if (max <= 0) {
    return items.map((p) => _RankedProduct(p, 0)).toList();
  }
  return items.map((p) => _RankedProduct(p, (p.revenue / max).clamp(0, 1))).toList();
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.points});
  final List<api.RevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Revenue Trend',
                  style: AppTypography.h3.copyWith(fontSize: 16)),
              Text('${points.length} day${points.length == 1 ? '' : 's'}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 140,
            child: points.isEmpty
                ? Center(
                    child: Text(
                      'No revenue data',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  )
                : CustomPaint(
                    painter: _SparklinePainter(
                      values: points.map((p) => p.revenue).toList(),
                    ),
                    size: const Size(double.infinity, 140),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values});
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;
    final path = Path();
    final fillPath = Path();
    final n = values.length;
    for (var i = 0; i < n; i++) {
      final norm = values[i] / safeMax;
      final x = n == 1 ? size.width / 2 : (i / (n - 1)) * size.width;
      final y =
          size.height - (norm * size.height * 0.85) - size.height * 0.05;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()..color = AppColors.primary.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}
