import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/list_helpers.dart';
import 'package:akhiyan_admin/src/features/products/presentation/categories_screen.dart' show CategoriesScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Brands list. Same shape as [CategoriesScreen] — read-only list of brand
/// cards driven by `brandsProvider`. Live-refreshes via the SSE `brands`
/// channel through the central `syncInvalidationProvider`.
class BrandsScreen extends ConsumerStatefulWidget {
  const BrandsScreen({super.key});

  @override
  ConsumerState<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends ConsumerState<BrandsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncBrands = ref.watch(brandsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Brands',
          style: context.h3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(brandsProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            ListSearchField(
              hint: 'Search brands...',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.md),
            asyncBrands.when(
              data: (list) => _BrandsList(query: _query, items: list),
              loading: () => const ListSkeleton(),
              error: (e, _) => ListInlineError(
                message: describeListError(e, 'Could not load brands'),
                onRetry: () => ref.invalidate(brandsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandsList extends StatelessWidget {
  const _BrandsList({required this.query, required this.items});
  final String query;
  final List<api.Brand> items;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visible = q.isEmpty
        ? items
        : items
            .where((b) =>
                b.name.toLowerCase().contains(q) ||
                b.slug.toLowerCase().contains(q))
            .toList();

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(
            q.isEmpty ? 'No brands yet' : 'No brands match "$query"',
            style: context.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final b in visible) ...[
          _BrandCard(brand: b),
          const SizedBox(height: AppSpacing.sm + 4),
        ],
      ],
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.brand});
  final api.Brand brand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xLarge),
      child: InkWell(
        onTap: () => context.push('/products'),
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        child: Container(
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
          child: Row(
            children: [
              ListThumbnail(
                  imageUrl: brand.logo, fallbackInitial: brand.name),
              const SizedBox(width: AppSpacing.md - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.name.isEmpty ? '(unnamed)' : brand.name,
                      style: context.h3.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onBackground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      brand.slug,
                      style: context.bodySm.copyWith(
                        color: AppColors.outline,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ListCountPill(
                  count: brand.productsCount, active: brand.isActive),
            ],
          ),
        ),
      ),
    );
  }
}
