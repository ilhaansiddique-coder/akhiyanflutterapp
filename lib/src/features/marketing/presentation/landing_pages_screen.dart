import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/list_helpers.dart';
import 'package:akhiyan_admin/src/features/marketing/presentation/landing_page_form_screen.dart' show LandingPageFormScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Marketing landing pages — list view. Driven by [landingPagesProvider]
/// which auto-refreshes on the `landing-pages` SSE channel, so edits made
/// on the web admin or another phone appear here within seconds.
///
/// Tapping a card opens [LandingPageFormScreen] for the focused mobile
/// editor (core fields only — see that file for what's editable on phone
/// vs web).
class LandingPagesScreen extends ConsumerStatefulWidget {
  const LandingPagesScreen({super.key});

  @override
  ConsumerState<LandingPagesScreen> createState() =>
      _LandingPagesScreenState();
}

class _LandingPagesScreenState extends ConsumerState<LandingPagesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncPages = ref.watch(landingPagesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Landing Pages',
          style: AppTypography.h3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New landing page',
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => _showNewPageSheet(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(landingPagesProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            ListSearchField(
              hint: 'Search landing pages...',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.md),
            asyncPages.when(
              data: (list) => _PagesList(query: _query, items: list),
              loading: () => const ListSkeleton(),
              error: (e, _) => ListInlineError(
                message: describeListError(e, 'Could not load landing pages'),
                onRetry: () => ref.invalidate(landingPagesProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewPageSheet(BuildContext ctx, WidgetRef ref) async {
    final created = await showModalBottomSheet<api.LandingPage>(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xLarge)),
      ),
      builder: (_) => const _NewLandingPageSheet(),
    );
    if (created != null && mounted) {
      ref.invalidate(landingPagesProvider);
      // Push straight into the editor — the user almost always wants to
      // continue filling out the page after creating the shell.
      ctx.push('/landing-pages/${created.id}');
    }
  }
}

class _PagesList extends StatelessWidget {
  const _PagesList({required this.query, required this.items});
  final String query;
  final List<api.LandingPage> items;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visible = q.isEmpty
        ? items
        : items
            .where((p) =>
                p.title.toLowerCase().contains(q) ||
                p.slug.toLowerCase().contains(q) ||
                (p.heroHeadline ?? '').toLowerCase().contains(q))
            .toList();

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(
            q.isEmpty
                ? 'No landing pages yet. Tap + to create one.'
                : 'No pages match "$query"',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final p in visible) ...[
          _PageCard(page: p),
          const SizedBox(height: AppSpacing.sm + 4),
        ],
      ],
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({required this.page});
  final api.LandingPage page;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xLarge),
      child: InkWell(
        onTap: () => context.push('/landing-pages/${page.id}'),
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
                  imageUrl: page.heroImage, fallbackInitial: page.title),
              const SizedBox(width: AppSpacing.md - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.title.isEmpty ? '(untitled)' : page.title,
                      style: AppTypography.h3.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onBackground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '/${page.slug}',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.outline,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((page.heroHeadline ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        page.heroHeadline!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ActiveBadge(active: page.isActive),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg =
        active ? AppColors.successContainer : AppColors.surfaceContainer;
    final fg = active
        ? AppColors.onSuccessContainer
        : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        active ? 'LIVE' : 'DRAFT',
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── New page bottom sheet ──────────────────────────────────────────────────

class _NewLandingPageSheet extends ConsumerStatefulWidget {
  const _NewLandingPageSheet();

  @override
  ConsumerState<_NewLandingPageSheet> createState() =>
      _NewLandingPageSheetState();
}

class _NewLandingPageSheetState
    extends ConsumerState<_NewLandingPageSheet> {
  final _title = TextEditingController();
  final _slug = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await ref.read(akhiyanApiProvider).landingPages.create(
            title: title,
            slug: _slug.text.trim().isEmpty ? null : _slug.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = describeListError(e, 'Could not create page');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(
        bottom: viewInsets.bottom,
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New Landing Page',
              style: AppTypography.h3
                  .copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _slug,
            decoration: const InputDecoration(
              labelText: 'Slug (optional — auto-generated)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
