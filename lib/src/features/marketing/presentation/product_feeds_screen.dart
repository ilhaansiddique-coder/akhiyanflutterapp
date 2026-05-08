import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/list_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product Feeds editor — full read+write surface.
///
/// Driven by [feedConfigProvider]. The bottom of the screen shows a stats
/// card (rows in feed, in-stock vs out-of-stock, on-sale count) so admins
/// can quickly verify the feed is healthy without leaving the app.
///
/// Live-refresh: a save here bumps the `feeds` SSE channel server-side, so
/// other admins see the new defaults within seconds without a manual
/// refresh.
class ProductFeedsScreen extends ConsumerStatefulWidget {
  const ProductFeedsScreen({super.key});

  @override
  ConsumerState<ProductFeedsScreen> createState() =>
      _ProductFeedsScreenState();
}

class _ProductFeedsScreenState extends ConsumerState<ProductFeedsScreen> {
  final _brand = TextEditingController();
  final _gpc = TextEditingController();
  final _siteUrl = TextEditingController();
  String _condition = 'new';
  bool _initialized = false;
  bool _saving = false;

  static const _conditions = ['new', 'refurbished', 'used'];

  @override
  void dispose() {
    _brand.dispose();
    _gpc.dispose();
    _siteUrl.dispose();
    super.dispose();
  }

  void _hydrate(api.FeedDefaults d) {
    if (_initialized) return;
    _initialized = true;
    _brand.text = d.brand ?? '';
    _gpc.text = d.googleProductCategory ?? '';
    _siteUrl.text = d.siteUrl ?? '';
    final c = (d.condition ?? 'new').toLowerCase();
    _condition = _conditions.contains(c) ? c : 'new';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(akhiyanApiProvider).feeds.save(
            brand: _brand.text.trim(),
            condition: _condition,
            googleProductCategory: _gpc.text.trim(),
            siteUrl: _siteUrl.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(feedConfigProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feed defaults saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeListError(e, 'Save failed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCfg = ref.watch(feedConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Product Feeds',
          style: AppTypography.h3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: asyncCfg.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not load feed config.\n$e',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        data: (cfg) {
          _hydrate(cfg.defaults);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(feedConfigProvider),
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                  children: [
                    _StatsCard(stats: cfg.stats),
                    const SizedBox(height: AppSpacing.md),
                    _DefaultsCard(
                      brandCtrl: _brand,
                      gpcCtrl: _gpc,
                      siteUrlCtrl: _siteUrl,
                      condition: _condition,
                      onConditionChanged: (v) =>
                          setState(() => _condition = v),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      MediaQuery.of(context).padding.bottom +
                          AppSpacing.sm,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      border: Border(
                        top: BorderSide(color: AppColors.slateBorder),
                      ),
                    ),
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('Save defaults'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final api.FeedStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        border: Border.all(color: AppColors.slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Feed health',
              style: AppTypography.h3.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.4)),
          const SizedBox(height: AppSpacing.md - 4),
          Row(
            children: [
              _Stat(label: 'Rows', value: stats.rowsInFeed.toString()),
              _Stat(
                  label: 'Active',
                  value: stats.activeProducts.toString()),
              _Stat(label: 'Total', value: stats.totalProducts.toString()),
            ],
          ),
          const SizedBox(height: AppSpacing.md - 4),
          Row(
            children: [
              _Stat(
                  label: 'In stock',
                  value: stats.inStock.toString(),
                  tone: _StatTone.good),
              _Stat(
                  label: 'Out',
                  value: stats.outOfStock.toString(),
                  tone: stats.outOfStock > 0
                      ? _StatTone.bad
                      : _StatTone.neutral),
              _Stat(label: 'On sale', value: stats.onSale.toString()),
            ],
          ),
          if (stats.activeFlashSales > 0) ...[
            const SizedBox(height: AppSpacing.sm + 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 4, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${stats.activeFlashSales} active flash sale${stats.activeFlashSales == 1 ? '' : 's'} feeding into ads',
                    style: AppTypography.bodySm
                        .copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _StatTone { neutral, good, bad }

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.tone = _StatTone.neutral,
  });

  final String label;
  final String value;
  final _StatTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _StatTone.good => AppColors.success,
      _StatTone.bad => AppColors.error,
      _StatTone.neutral => AppColors.onBackground,
    };
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              color: AppColors.outline,
              fontSize: 10,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultsCard extends StatelessWidget {
  const _DefaultsCard({
    required this.brandCtrl,
    required this.gpcCtrl,
    required this.siteUrlCtrl,
    required this.condition,
    required this.onConditionChanged,
  });

  final TextEditingController brandCtrl;
  final TextEditingController gpcCtrl;
  final TextEditingController siteUrlCtrl;
  final String condition;
  final ValueChanged<String> onConditionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        border: Border.all(color: AppColors.slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Defaults',
              style: AppTypography.h3.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(
            'Applied to every product in the feed unless the product '
            'overrides the value.',
            style: AppTypography.bodySm
                .copyWith(color: AppColors.outline, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md - 4),
          _Field(label: 'Brand', controller: brandCtrl),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DropdownButtonFormField<String>(
              initialValue: condition,
              decoration: const InputDecoration(
                labelText: 'Condition',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'new', child: Text('New')),
                DropdownMenuItem(
                    value: 'refurbished', child: Text('Refurbished')),
                DropdownMenuItem(value: 'used', child: Text('Used')),
              ],
              onChanged: (v) {
                if (v != null) onConditionChanged(v);
              },
            ),
          ),
          _Field(
            label: 'Google product category',
            controller: gpcCtrl,
            helper:
                'e.g. "Apparel & Accessories > Clothing" or the numeric '
                'taxonomy id.',
          ),
          _Field(
            label: 'Site URL',
            controller: siteUrlCtrl,
            helper: 'Public storefront base URL, no trailing slash.',
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
