import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/akhiyan_api.dart' as api;
import '../../../core/api/api_providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/coming_soon.dart';
import '../../../core/widgets/page_loading_overlay.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

/// Customers list — wired to `/customers` via [customersListProvider].
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Page number the user just tapped that is currently being fetched.
  int? _loadingPage;

  void _goToPage(int p) {
    setState(() => _loadingPage = p);
    ref.read(customersListProvider.notifier).goToPage(p);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersListProvider);
    if (!state.loading && _loadingPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(customersListProvider).loading) {
          setState(() => _loadingPage = null);
        }
      });
    }
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
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        child: const Icon(Icons.person_add, size: 26),
      ),
      body: Builder(
        builder: (_) {
          if (state.loading && state.items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl + AppSpacing.lg,
              ),
              children: [
                for (int i = 0; i < 8; i++) ...const [
                  _CustomerCardSkeleton(),
                  SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          }
          if (state.error != null && state.items.isEmpty) {
            final e = state.error!;
            if (e is api.ApiException && e.isNotFound) {
              return comingSoonBody('Customers');
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(_describeError(e), textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(customersListProvider.notifier)
                          .refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final visible = state.items.where((c) {
            if (_query.isEmpty) return true;
            final q = _query.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                (c.email ?? '').toLowerCase().contains(q);
          }).toList();
          final isPageSwitching = state.loading && state.items.isNotEmpty;
          final list = RefreshIndicator(
            onRefresh: () =>
                ref.read(customersListProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl + AppSpacing.lg,
              ),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x05000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.outline,
                        size: 20,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLowest,
                      hintStyle: AppTypography.bodyMd.copyWith(
                        color: AppColors.outline,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        borderSide:
                            const BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        borderSide:
                            const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Customers',
                      style: AppTypography.h1.copyWith(
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onBackground,
                      ),
                    ),
                    Material(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md - 4,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.tune,
                                size: 18,
                                color: AppColors.onPrimaryFixed,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Filters',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.onPrimaryFixed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (visible.isEmpty && state.items.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'No customers match "$_query"',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else if (state.items.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'No customers yet',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final c in visible) ...[
                    _CustomerCard(
                      customer: c,
                      onTap: () => context.push('/customers/${c.id}'),
                    ),
                    const SizedBox(height: AppSpacing.sm + 4),
                  ],
                PaginationBar(
                  currentPage: state.currentPage,
                  totalPages: state.totalPages,
                  loadingPage: isPageSwitching ? _loadingPage : null,
                  onPageChanged: _goToPage,
                ),
              ],
            ),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: isPageSwitching,
                child: AnimatedOpacity(
                  opacity: isPageSwitching ? 0.6 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  child: list,
                ),
              ),
              if (isPageSwitching)
                PageLoadingOverlay(
                  targetPage: _loadingPage ?? state.currentPage,
                ),
            ],
          );
        },
      ),
    );
  }
}

String _describeError(Object e) {
  if (e is api.ApiException) return e.message;
  if (e is api.NetworkException) return 'No internet connection';
  return 'Could not load customers';
}

/// Stable avatar palette derived from the customer id so two renders of the
/// same customer always pick the same colour.
({Color bg, Color fg}) _avatarPalette(String id) {
  const palette = <(Color, Color)>[
    (Color(0xFFD1FAE5), Color(0xFF047857)), // emerald
    (Color(0xFFFFEDD5), Color(0xFFC2410C)), // orange
    (Color(0xFFDBEAFE), Color(0xFF1D4ED8)), // blue
    (Color(0xFFEDE9FE), Color(0xFF6D28D9)), // purple
    (Color(0xFFFFE4E6), Color(0xFFBE123C)), // rose
    (Color(0xFFFEF9C3), Color(0xFFA16207)), // amber
  ];
  final hash = id.codeUnits.fold<int>(0, (a, b) => (a + b) & 0x7fffffff);
  final pick = palette[hash % palette.length];
  return (bg: pick.$1, fg: pick.$2);
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

// ─── Customer card ─────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onTap});
  final api.CustomerListItem customer;
  final VoidCallback onTap;

  String _formatTaka(num n) {
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _avatarPalette(customer.id);
    final initials = _initialsOf(customer.name);
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF1F7),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(AppRadius.large),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.bg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: AppTypography.h3.copyWith(
                    color: palette.fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name.isEmpty ? 'Unknown' : customer.name,
                      style: AppTypography.h3.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onBackground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.email ?? customer.phone ?? '',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.outline,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm + 4),
                    Container(
                      padding: const EdgeInsets.only(top: AppSpacing.sm + 4),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.borderSubtle),
                        ),
                      ),
                      child: Row(
                        children: [
                          _MetaCol(
                            label: 'ORDERS',
                            value: '${customer.ordersCount}',
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          _MetaCol(
                            label: 'SPEND',
                            value:
                                '৳ ${_formatTaka(customer.totalSpent)}',
                            valueColor: AppColors.primary,
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

class _MetaCol extends StatelessWidget {
  const _MetaCol({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.outline,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodySm.copyWith(
            color: valueColor ?? AppColors.onBackground,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ─── Customer card skeleton (first-load placeholder) ────────────────────

class _CustomerCardSkeleton extends StatelessWidget {
  const _CustomerCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F7),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 48, height: 48, radius: 24),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 160, fontSize: 14),
                  SizedBox(height: 6),
                  SkeletonText(width: 200, fontSize: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
