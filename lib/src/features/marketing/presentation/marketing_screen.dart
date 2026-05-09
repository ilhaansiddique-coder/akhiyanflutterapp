import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_card.dart';
import 'package:akhiyan_admin/src/core/widgets/app_shell_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Marketing hub. Merged from `marketing_overview_2/code.html` and the prior
/// Flutter port:
/// - Page heading + subtitle
/// - Performance hero (purple, conversions stat + 7-bar mini chart + pulsing growth pill)
/// - 2×2 bento of tools (Coupons / Flash Sales / Shortlinks / Analytics) with per-tool indicators
/// - Recent campaigns as separate tappable cards
/// - FAB for "create" entry
class MarketingScreen extends ConsumerWidget {
  const MarketingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsDataProvider);
    final orders = analyticsAsync.value?.stats.orders;
    final revenue = analyticsAsync.value?.stats.revenue;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: const AppShellAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/coupons/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl + AppSpacing.md,
        ),
        children: [
          const _PageHeading(),
          const SizedBox(height: AppSpacing.lg),
          _PerformanceHero(orders: orders, revenue: revenue),
          const SizedBox(height: AppSpacing.lg),
          const _ToolsGrid(),
          const SizedBox(height: AppSpacing.lg),
          const _RecentCampaigns(),
        ],
      ),
    );
  }
}

// ─── Page heading ────────────────────────────────────────────────────────

class _PageHeading extends StatelessWidget {
  const _PageHeading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Marketing Overview',
          style: context.h1.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track performance and manage active campaigns across all channels.',
          style: context.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Performance hero ────────────────────────────────────────────────────

class _PerformanceHero extends StatelessWidget {
  const _PerformanceHero({this.orders, this.revenue});
  final int? orders;
  final double? revenue;

  @override
  Widget build(BuildContext context) {
    final headline = orders == null ? '—' : '$orders Orders';
    final subline = revenue == null
        ? 'From marketing campaigns this month'
        : 'Revenue: ৳${revenue!.toStringAsFixed(0)} this period';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg - 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.large + 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Stack(
          children: [
            // Decorative blurred circle (bottom-right glow)
            Positioned(
              right: -40,
              bottom: -40,
              child: Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  color: AppColors.inversePrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GROWTH PERFORMANCE',
                      style: context.caption.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const _GrowthPill(label: '+12.4%'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  headline,
                  style: context.h2.copyWith(
                    color: AppColors.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subline,
                  style: context.bodySm.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _MiniBarChart(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "+12.4%" pill with a pulsing green status dot.
class _GrowthPill extends StatefulWidget {
  const _GrowthPill({required this.label});
  final String label;

  @override
  State<_GrowthPill> createState() => _GrowthPillState();
}

class _GrowthPillState extends State<_GrowthPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) => Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withValues(
                  alpha: 0.55 + 0.45 * _ctrl.value,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: context.caption.copyWith(
              color: const Color(0xFF34D399),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Static 7-bar chart with gradient opacity. Stand-in for a real chart —
/// the heights and opacities follow the mockup verbatim.
class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart();

  static const _bars = [
    (16.0, 0.20),
    (24.0, 0.30),
    (32.0, 0.40),
    (40.0, 0.50),
    (28.0, 0.40),
    (44.0, 0.60),
    (48.0, 0.80),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _bars.length; i++) ...[
            Expanded(
              child: Container(
                height: _bars[i].$1,
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: _bars[i].$2),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ),
            ),
            if (i < _bars.length - 1) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}

// ─── Tools bento grid ────────────────────────────────────────────────────

class _ToolsGrid extends StatelessWidget {
  const _ToolsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.gutter,
      crossAxisSpacing: AppSpacing.gutter,
      childAspectRatio: 1.25,
      children: [
        _ToolCard(
          icon: Icons.link,
          iconBg: AppColors.warningContainer,
          iconFg: AppColors.warning,
          title: 'Shortlinks',
          description: 'Trackable URLs for social media.',
          indicator: const _StatIndicator(value: '12.8k', caption: 'Total Clicks'),
          onTap: () => context.push('/shortlinks'),
        ),
        _ToolCard(
          icon: Icons.analytics_outlined,
          iconBg: AppColors.tertiaryFixed,
          iconFg: AppColors.tertiary,
          title: 'Analytics',
          description: 'Last 30-day performance trends.',
          indicator: const _StatIndicator(value: '+8%', caption: 'Growth'),
          onTap: () => context.push('/analytics'),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.description,
    required this.indicator,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String description;
  final Widget indicator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 16, AppSpacing.md, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(icon, color: iconFg, size: 22),
              ),
              const Spacer(),
              indicator,
            ],
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: context.h3.copyWith(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: context.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatIndicator extends StatelessWidget {
  const _StatIndicator({required this.value, required this.caption});
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: context.h3.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: context.caption.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Recent campaigns ────────────────────────────────────────────────────

/// Recent campaigns list — placeholder while a dedicated `/marketing/campaigns`
/// rollup is not exposed by the API. Renders an empty hint instead of fake
/// rows so the screen reflects backend reality.
class _RecentCampaigns extends StatelessWidget {
  const _RecentCampaigns();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Campaigns',
              style: context.h2.copyWith(fontSize: 20),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Text(
              'No active campaigns yet',
              style: context.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

