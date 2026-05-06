import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_drawer.dart';

/// Coupons / Marketing manager — port of the latest design spec
/// (`coupons_manager.html`). Layout: header row (title + subtitle + CTA),
/// 2×2 quick-stats bento grid, underlined filter tabs, vertical list of
/// rich coupon cards with state-aware footers.
class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  _CouponFilter _filter = _CouponFilter.all;

  List<_Coupon> get _visible {
    if (_filter == _CouponFilter.all) return _coupons;
    return _coupons.where((c) => c.status == _filter.matchingStatus!).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: const Icon(Icons.menu, color: AppColors.primary),
          ),
        ),
        title: Text(
          'Akhiyan Admin',
          style: AppTypography.h3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  'AU',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/coupons/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md)
            .copyWith(bottom: AppSpacing.xl + AppSpacing.lg),
        children: [
          const _HeaderRow(),
          const SizedBox(height: AppSpacing.lg),
          const _StatsGrid(),
          const SizedBox(height: AppSpacing.lg),
          _FilterTabs(
            active: _filter,
            onChange: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final c in _visible) ...[
            _CouponCard(coupon: c),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

// ─── Header row: title + subtitle + Create Coupon CTA ──────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marketing',
                style: AppTypography.h2.copyWith(
                  fontSize: 22,
                  height: 1.2,
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Manage your store's promotional offers and coupons",
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Builder(
          builder: (ctx) => ElevatedButton.icon(
            onPressed: () => ctx.push('/coupons/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              textStyle: AppTypography.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Quick stats bento grid (2×2 on mobile) ────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm + 4,
      crossAxisSpacing: AppSpacing.sm + 4,
      childAspectRatio: 1.7,
      children: const [
        _StatTile(
          label: 'ACTIVE COUPONS',
          value: '12',
          accent: _StatAccent.deltaUp(label: '+2'),
        ),
        _StatTile(
          label: 'TOTAL REDEEMED',
          value: '842',
          accent: _StatAccent.icon(icon: Icons.trending_up),
        ),
        _StatTile(
          label: 'CONVERSION RATE',
          value: '4.8%',
          accent: _StatAccent.deltaUp(label: '↑ 1.2%', primary: true),
        ),
        _StatTile(
          label: 'AVG. SAVINGS',
          value: '৳340',
          accent: _StatAccent.icon(icon: Icons.savings_outlined),
        ),
      ],
    );
  }
}

class _StatAccent {
  final String? deltaLabel;
  final IconData? icon;
  final bool primaryDelta;
  const _StatAccent.deltaUp({required String label, bool primary = false})
      : deltaLabel = label,
        icon = null,
        primaryDelta = primary;
  const _StatAccent.icon({required this.icon})
      : deltaLabel = null,
        primaryDelta = false;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
  });
  final String label;
  final String value;
  final _StatAccent accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.outline,
              letterSpacing: 0.4,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppTypography.h1.copyWith(
                    fontSize: 22,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onBackground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (accent.deltaLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.primaryDelta
                        ? AppColors.primaryFixed
                        : AppColors.successContainer,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    accent.deltaLabel!,
                    style: AppTypography.caption.copyWith(
                      color: accent.primaryDelta
                          ? AppColors.onPrimaryFixed
                          : AppColors.onSuccessContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (accent.icon != null)
                Icon(accent.icon, size: 18, color: AppColors.outlineVariant),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Underlined filter tabs ────────────────────────────────────────────────

enum _CouponFilter {
  all('All Coupons', null),
  active('Active', _CouponStatus.active),
  scheduled('Scheduled', _CouponStatus.scheduled),
  expired('Expired', _CouponStatus.expired);

  const _CouponFilter(this.label, this.matchingStatus);
  final String label;
  final _CouponStatus? matchingStatus;
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.active, required this.onChange});
  final _CouponFilter active;
  final ValueChanged<_CouponFilter> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in _CouponFilter.values)
              _Tab(
                label: f.label,
                selected: active == f,
                onTap: () => onChange(f),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 8, AppSpacing.md, 10),
        margin: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySm.copyWith(
            color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Coupon card ───────────────────────────────────────────────────────────

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});
  final _Coupon coupon;

  bool get _isExpired => coupon.status == _CouponStatus.expired;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: _isExpired
            ? AppColors.surfaceContainerLow
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: _isExpired
              ? AppColors.outlineVariant
              : AppColors.borderSubtle,
        ),
        boxShadow: _isExpired
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md + 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TypeBadge(label: coupon.type, dim: _isExpired),
                          const SizedBox(height: 6),
                          Text(
                            coupon.headline,
                            style: AppTypography.h1.copyWith(
                              fontSize: 24,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: _isExpired
                                  ? AppColors.outline
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusPill(status: coupon.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  coupon.title,
                  style: AppTypography.bodyMd.copyWith(
                    color: _isExpired
                        ? AppColors.outline
                        : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _CodeBox(code: coupon.code, expired: _isExpired),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _MetaCol(
                        label: 'USAGE',
                        value: coupon.usage,
                        dim: _isExpired,
                      ),
                    ),
                    Expanded(
                      child: _MetaCol(
                        label: coupon.dateLabel,
                        value: coupon.date,
                        dim: _isExpired,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md + 4,
              vertical: AppSpacing.sm + 4,
            ),
            decoration: BoxDecoration(
              color: _isExpired
                  ? AppColors.surfaceContainer
                  : const Color(0xFFFAFAFB),
              border: const Border(
                top: BorderSide(color: AppColors.borderSubtle),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _FooterLeading(coupon: coupon)),
                IconButton(
                  onPressed: () {},
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    coupon.status == _CouponStatus.expired
                        ? Icons.restore
                        : coupon.status == _CouponStatus.scheduled
                            ? Icons.edit_outlined
                            : Icons.more_horiz,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return _isExpired ? Opacity(opacity: 0.85, child: card) : card;
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.dim});
  final String label;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dim ? AppColors.surfaceContainer : AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: dim ? AppColors.outline : AppColors.onPrimaryFixed,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final _CouponStatus status;

  ({Color bg, Color fg, Color dot, String label}) get _meta {
    switch (status) {
      case _CouponStatus.active:
        return (
          bg: AppColors.successContainer,
          fg: AppColors.onSuccessContainer,
          dot: AppColors.success,
          label: 'Active'
        );
      case _CouponStatus.scheduled:
        return (
          bg: AppColors.warningContainer,
          fg: AppColors.onWarningContainer,
          dot: AppColors.warning,
          label: 'Scheduled'
        );
      case _CouponStatus.expired:
        return (
          bg: AppColors.surfaceContainer,
          fg: AppColors.onSurfaceVariant,
          dot: AppColors.outline,
          label: 'Expired'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: m.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: m.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            m.label,
            style: AppTypography.caption.copyWith(
              color: m.fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code, required this.expired});
  final String code;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 4,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: expired
            ? AppColors.surfaceContainerLowest
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: expired
            ? Border.all(color: AppColors.outlineVariant)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              code,
              style: GoogleFonts.jetBrainsMono(
                color: expired ? AppColors.outline : AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (expired)
            const Icon(Icons.lock_outline,
                size: 18, color: AppColors.outlineVariant)
          else
            Builder(
              builder: (ctx) => InkWell(
                onTap: () {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Copied: $code'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy_outlined,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaCol extends StatelessWidget {
  const _MetaCol({
    required this.label,
    required this.value,
    required this.dim,
  });
  final String label;
  final String value;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.outline,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodySm.copyWith(
            color: dim ? AppColors.outline : AppColors.onBackground,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _FooterLeading extends StatelessWidget {
  const _FooterLeading({required this.coupon});
  final _Coupon coupon;

  @override
  Widget build(BuildContext context) {
    if (coupon.status == _CouponStatus.scheduled) {
      return Row(
        children: [
          const Icon(Icons.schedule, size: 14, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            coupon.footerNote ?? '',
            style: AppTypography.caption.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      );
    }
    if (coupon.status == _CouponStatus.expired) {
      return Text(
        coupon.footerNote ?? '',
        style: AppTypography.bodySm.copyWith(
          color: AppColors.outline,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      );
    }
    if (coupon.users != null && coupon.users!.isNotEmpty) {
      return _AvatarStack(initials: coupon.users!);
    }
    return Text(
      coupon.footerNote ?? '',
      style: AppTypography.bodySm.copyWith(
        color: AppColors.outline,
        fontSize: 12,
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.initials});
  final List<String> initials;

  static const _palette = <(Color, Color)>[
    (Color(0xFFE5DEFF), Color(0xFF4F378A)),
    (Color(0xFFFCE4EC), Color(0xFFC2185B)),
    (Color(0xFFE0E7FF), Color(0xFF3730A3)),
    (Color(0xFFE5E7EB), Color(0xFF4B5563)),
  ];

  @override
  Widget build(BuildContext context) {
    final n = initials.length;
    return SizedBox(
      width: ((n - 1) * 18 + 24).toDouble(),
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: (i * 18).toDouble(),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _palette[i % _palette.length].$1,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _palette[i % _palette.length].$2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Mock data ─────────────────────────────────────────────────────────────

enum _CouponStatus { active, scheduled, expired }

class _Coupon {
  const _Coupon({
    required this.code,
    required this.title,
    required this.type,
    required this.headline,
    required this.status,
    required this.usage,
    required this.dateLabel,
    required this.date,
    this.users,
    this.footerNote,
  });

  final String code;
  final String title;
  final String type;
  final String headline;
  final _CouponStatus status;
  final String usage;
  final String dateLabel;
  final String date;
  final List<String>? users;
  final String? footerNote;
}

const _coupons = <_Coupon>[
  _Coupon(
    code: 'NYBLAST20',
    title: 'New Year Blast Promotion 2024',
    type: 'Percentage Off',
    headline: '20% OFF',
    status: _CouponStatus.active,
    usage: '142 / 500',
    dateLabel: 'Expires',
    date: '31 Jan, 2024',
    users: ['JS', 'MK', '+8'],
  ),
  _Coupon(
    code: 'LOYAL500',
    title: 'Loyal Customer Appreciation',
    type: 'Fixed Amount',
    headline: '৳500 OFF',
    status: _CouponStatus.active,
    usage: 'Unlimited',
    dateLabel: 'Expires',
    date: 'No Expiry',
    footerNote: 'Last used 2 hrs ago',
  ),
  _Coupon(
    code: 'WINTER10',
    title: 'Winter Sale Early Bird',
    type: 'Percentage Off',
    headline: '10% OFF',
    status: _CouponStatus.expired,
    usage: '200 / 200',
    dateLabel: 'Expired On',
    date: '15 Dec, 2023',
    footerNote: 'Archived Automatically',
  ),
  _Coupon(
    code: 'EIDMUBARAK',
    title: 'Upcoming Eid-ul-Fitr Special Campaign',
    type: 'Free Shipping',
    headline: 'FREE SHIP',
    status: _CouponStatus.scheduled,
    usage: '0 / 1000',
    dateLabel: 'Starts On',
    date: '10 Apr, 2024',
    footerNote: 'Starts in 12 days',
  ),
];
