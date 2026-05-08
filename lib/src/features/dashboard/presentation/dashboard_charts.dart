import 'dart:math' as math;

import 'package:akhiyan_admin/api/akhiyan_api.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:flutter/material.dart';

/// 7-day orders bar chart. Hand-rolled with CustomPaint to avoid pulling
/// in `fl_chart` / `charts_flutter` for two simple visualisations — keeps
/// the supply chain tight and the rendering cost trivial.
///
/// Reads from [RevenuePoint.orders] not `revenue` so the bars match the
/// "Last 7 Days Orders" framing on the web admin's mobile dashboard.
class OrdersBarChartCard extends StatelessWidget {
  const OrdersBarChartCard({
    super.key,
    required this.points,
  });

  final List<RevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    // Trim to last 7 days defensively — server already returns 7 when
    // period=7d, but if the response is longer we want the most recent
    // tail, not the first 7.
    final last7 =
        points.length <= 7 ? points : points.sublist(points.length - 7);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        border: Border.all(color: AppColors.slateBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: const Icon(Icons.bar_chart_outlined,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  'Last 7 Days Orders',
                  style: AppTypography.h3.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onBackground),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (last7.isEmpty)
            const _EmptyChartHint(message: 'No order data for the last 7 days yet.')
          else
            SizedBox(
              height: 180,
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarChartPainter(points: last7),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.points});

  final List<RevenuePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Reserve the bottom 22px for the day labels so the bars don't crash
    // into the axis. Leave some top headroom for the value labels.
    const labelGutter = 22.0;
    const topGutter = 18.0;
    final chartArea =
        Rect.fromLTWH(0, topGutter, size.width, size.height - topGutter - labelGutter);

    final maxOrders = points.fold<int>(0, (a, p) => p.orders > a ? p.orders : a);
    // Round up to a sensible scale — without this a single tall bar fills
    // the chart and the others are invisible. `max(1, …)` avoids /0 when
    // every day is empty.
    final scale = math.max(1, maxOrders);

    // Bar geometry: even slots, 60% bar / 40% gap.
    final slotWidth = size.width / points.length;
    const barRatio = 0.55;

    final barPaint = Paint()..style = PaintingStyle.fill;
    final labelStyle = AppTypography.caption.copyWith(
      fontSize: 10,
      color: AppColors.outline,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );
    final valueStyle = AppTypography.caption.copyWith(
      fontSize: 10,
      color: AppColors.onBackground,
      fontWeight: FontWeight.w800,
    );

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final pct = p.orders / scale;
      final barHeight = chartArea.height * pct;
      final left = slotWidth * i + slotWidth * (1 - barRatio) / 2;
      final width = slotWidth * barRatio;
      final top = chartArea.bottom - barHeight;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, math.max(2, barHeight)),
        const Radius.circular(6),
      );
      // Alternating tone — primary for "today + odd days", primary-light
      // for the others — matches the web admin's striped bar style.
      barPaint.color =
          i.isEven ? AppColors.primary : AppColors.primaryLight;
      canvas.drawRRect(rect, barPaint);

      // Value label above each bar (skip 0 to keep the chart clean).
      if (p.orders > 0) {
        _drawText(
          canvas,
          '${p.orders}',
          valueStyle,
          Offset(left + width / 2, top - 14),
          align: TextAlign.center,
        );
      }

      // Day label under the bar — short weekday like "Mon", "Tue" — falls
      // back to the date if parse fails so we never blank out an axis.
      _drawText(
        canvas,
        _shortDayLabel(p.date),
        labelStyle,
        Offset(left + width / 2, chartArea.bottom + 4),
        align: TextAlign.center,
      );
    }
  }

  static const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _shortDayLabel(String iso) {
    try {
      final d = DateTime.parse(iso);
      return _weekdayShort[d.weekday - 1];
    } catch (_) {
      return iso.length >= 5 ? iso.substring(5) : iso;
    }
  }

  void _drawText(Canvas canvas, String text, TextStyle style, Offset center,
      {TextAlign align = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.points != points;
}

// ─── Donut chart ────────────────────────────────────────────────────────────

class StatusDonutCard extends StatelessWidget {
  const StatusDonutCard({super.key, required this.statusBreakdown});

  final Map<String, int> statusBreakdown;

  /// Stable colour assignment per status. Keeps "pending" amber across
  /// rebuilds even when the order of statuses in the map changes.
  static const _statusColors = <String, Color>{
    'delivered': AppColors.success,
    'confirmed': AppColors.success,
    'courier_sent': AppColors.secondary,
    'processing': AppColors.info,
    'pending': AppColors.warning,
    'on_hold': AppColors.outline,
    'cancelled': AppColors.error,
    'returned': AppColors.tertiary,
    'trashed': AppColors.outline,
  };

  static const _statusLabels = <String, String>{
    'delivered': 'Delivered',
    'confirmed': 'Confirmed',
    'courier_sent': 'Courier Sent',
    'processing': 'Processing',
    'pending': 'Pending',
    'on_hold': 'On Hold',
    'cancelled': 'Cancelled',
    'returned': 'Returned',
    'trashed': 'Trashed',
  };

  @override
  Widget build(BuildContext context) {
    final entries = statusBreakdown.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        border: Border.all(color: AppColors.slateBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: const Icon(Icons.donut_large_outlined,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  'Order Status Breakdown',
                  style: AppTypography.h3.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onBackground),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (entries.isEmpty)
            const _EmptyChartHint(message: 'No orders in the selected period.')
          else
            Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      slices: entries,
                      total: total,
                      colorOf: (k) =>
                          _statusColors[k] ?? AppColors.outline,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: AppTypography.h3.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onBackground),
                          ),
                          Text(
                            'orders',
                            style: AppTypography.bodySm.copyWith(
                                fontSize: 11,
                                color: AppColors.outline,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in entries)
                        _LegendRow(
                          color: _statusColors[e.key] ?? AppColors.outline,
                          label: _statusLabels[e.key] ?? e.key,
                          count: e.value,
                          pct: total == 0 ? 0 : (e.value / total * 100),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.colorOf,
  });

  final List<MapEntry<String, int>> slices;
  final int total;
  final Color Function(String) colorOf;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2 - 4,
    );
    final ringWidth = rect.width * 0.22;

    var startAngle = -math.pi / 2; // 12 o'clock
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.butt;

    for (final s in slices) {
      final sweep = (s.value / total) * 2 * math.pi;
      paint.color = colorOf(s.key);
      // Inset by half stroke width so the ring doesn't get clipped.
      canvas.drawArc(
        rect.deflate(ringWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices || old.total != total;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.count,
    required this.pct,
  });

  final Color color;
  final String label;
  final int count;
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                  fontSize: 11,
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: AppTypography.bodySm.copyWith(
                fontSize: 11,
                color: AppColors.outline,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartHint extends StatelessWidget {
  const _EmptyChartHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.bodySm.copyWith(
            color: AppColors.outline, fontSize: 12),
      ),
    );
  }
}

/// Skeleton placeholder shown while the analytics fetch is in flight.
/// Matches the height of the loaded charts so the layout doesn't jump
/// when data arrives.
class DashboardChartsSkeleton extends StatelessWidget {
  const DashboardChartsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.xLarge),
            border: Border.all(color: AppColors.slateBorder),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.xLarge),
            border: Border.all(color: AppColors.slateBorder),
          ),
        ),
      ],
    );
  }
}
