import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/list_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Focused mobile editor for a single landing page.
///
/// **Editable on mobile:** title, slug, active toggle, hero block (headline,
/// subheadline, image URL, CTA, badge, trust text), primary colour, meta
/// title/description.
///
/// **Read-only on mobile (edit on web):** the rich JSON arrays — features,
/// testimonials, FAQ, problem points, how-it-works, sections list. These
/// each need rich array editors that don't fit a phone keyboard, so we
/// preserve them verbatim on save (`LandingPagesApi.update` re-emits the
/// raw values from the original payload). A summary card shows what's
/// stored so the admin knows the data is intact.
class LandingPageFormScreen extends ConsumerStatefulWidget {
  const LandingPageFormScreen({super.key, required this.pageId});

  final String pageId;

  @override
  ConsumerState<LandingPageFormScreen> createState() =>
      _LandingPageFormScreenState();
}

class _LandingPageFormScreenState
    extends ConsumerState<LandingPageFormScreen> {
  // Controllers are created on demand once the initial fetch resolves.
  // Tracked here so dispose() can release them.
  final _ctrls = <String, TextEditingController>{};
  bool _initialized = false;
  bool _isActive = true;
  bool _saving = false;
  bool _deleting = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key, [String initial = '']) {
    return _ctrls.putIfAbsent(
        key, () => TextEditingController(text: initial));
  }

  void _hydrate(api.LandingPage page) {
    if (_initialized) return;
    _initialized = true;
    _isActive = page.isActive;
    _ctrl('title', page.title);
    _ctrl('slug', page.slug);
    _ctrl('heroHeadline', page.heroHeadline ?? '');
    _ctrl('heroSubheadline', page.heroSubheadline ?? '');
    _ctrl('heroImage', page.heroImage ?? '');
    _ctrl('heroCta', page.heroCta ?? '');
    _ctrl('heroBadge', page.heroBadge ?? '');
    _ctrl('heroTrustText', page.heroTrustText ?? '');
    _ctrl('primaryColor', page.primaryColor ?? '#0f5931');
    _ctrl('metaTitle', page.metaTitle ?? '');
    _ctrl('metaDescription', page.metaDescription ?? '');
  }

  Future<void> _save(api.LandingPage base) async {
    final title = _ctrl('title').text.trim();
    if (title.isEmpty) {
      _toast('Title is required');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(akhiyanApiProvider).landingPages.update(
            base.id,
            base: base,
            title: title,
            slug: _ctrl('slug').text.trim().isEmpty
                ? null
                : _ctrl('slug').text.trim(),
            isActive: _isActive,
            heroHeadline: _nullable('heroHeadline'),
            heroSubheadline: _nullable('heroSubheadline'),
            heroImage: _nullable('heroImage'),
            heroCta: _nullable('heroCta'),
            heroBadge: _nullable('heroBadge'),
            heroTrustText: _nullable('heroTrustText'),
            primaryColor: _ctrl('primaryColor').text.trim().isEmpty
                ? null
                : _ctrl('primaryColor').text.trim(),
            metaTitle: _nullable('metaTitle'),
            metaDescription: _nullable('metaDescription'),
          );
      if (!mounted) return;
      // Refresh both the list (for the badge / hero preview) and the
      // detail (in case slug or anything else got rewritten by the
      // server's uniqueSlug logic).
      ref.invalidate(landingPagesProvider);
      ref.invalidate(landingPageDetailProvider(base.id));
      _toast('Saved');
    } catch (e) {
      if (!mounted) return;
      _toast(describeListError(e, 'Save failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Empty strings save as null (the schema allows null on hero fields).
  /// Without this, a cleared field saves as `""` and the storefront
  /// renders a blank hero subhead instead of falling back to defaults.
  String _nullable(String key) => _ctrl(key).text.trim();

  Future<void> _confirmDelete(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this landing page?'),
        content: Text(
            '"$title" will be removed permanently. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(akhiyanApiProvider).landingPages.delete(id);
      if (!mounted) return;
      ref.invalidate(landingPagesProvider);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      _toast(describeListError(e, 'Delete failed'));
      setState(() => _deleting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncPage = ref.watch(landingPageDetailProvider(widget.pageId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          asyncPage.maybeWhen(
            data: (p) => p.title.isEmpty ? 'Edit page' : p.title,
            orElse: () => 'Edit page',
          ),
          style: AppTypography.h3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          asyncPage.maybeWhen(
            data: (p) => IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.error),
              onPressed:
                  _deleting ? null : () => _confirmDelete(p.id, p.title),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: asyncPage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not load page.\n$e',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        data: (page) {
          _hydrate(page);
          return _Form(
            page: page,
            ctrlOf: _ctrl,
            isActive: _isActive,
            onActiveChanged: (v) => setState(() => _isActive = v),
            saving: _saving,
            onSave: () => _save(page),
          );
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.page,
    required this.ctrlOf,
    required this.isActive,
    required this.onActiveChanged,
    required this.saving,
    required this.onSave,
  });

  final api.LandingPage page;
  final TextEditingController Function(String) ctrlOf;
  final bool isActive;
  final ValueChanged<bool> onActiveChanged;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            // Bottom padding leaves room for the floating Save bar so
            // the last form field isn't covered.
            96,
          ),
          children: [
            _Section(
              title: 'Basics',
              children: [
                _Field(label: 'Title', controller: ctrlOf('title')),
                _Field(
                    label: 'Slug',
                    controller: ctrlOf('slug'),
                    helper:
                        'Used in the public URL. Server will deduplicate '
                        'on save.'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SwitchListTile(
                    value: isActive,
                    onChanged: onActiveChanged,
                    title: const Text('Live'),
                    subtitle: Text(
                      isActive
                          ? 'Visible to visitors'
                          : 'Saved as draft, not public',
                      style: AppTypography.bodySm.copyWith(
                          color: AppColors.outline, fontSize: 12),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Hero',
              children: [
                _Field(
                    label: 'Headline',
                    controller: ctrlOf('heroHeadline')),
                _Field(
                    label: 'Subheadline',
                    controller: ctrlOf('heroSubheadline'),
                    maxLines: 3),
                _Field(
                    label: 'Image URL',
                    controller: ctrlOf('heroImage'),
                    helper: 'Direct URL to a hero image or video.'),
                _Field(
                    label: 'CTA button text',
                    controller: ctrlOf('heroCta')),
                _Field(label: 'Badge', controller: ctrlOf('heroBadge')),
                _Field(
                    label: 'Trust text',
                    controller: ctrlOf('heroTrustText')),
              ],
            ),
            _Section(
              title: 'Branding',
              children: [
                _Field(
                    label: 'Primary colour (hex)',
                    controller: ctrlOf('primaryColor'),
                    helper: 'Falls back to #0f5931 when blank.'),
              ],
            ),
            _Section(
              title: 'SEO',
              children: [
                _Field(
                    label: 'Meta title', controller: ctrlOf('metaTitle')),
                _Field(
                    label: 'Meta description',
                    controller: ctrlOf('metaDescription'),
                    maxLines: 3),
              ],
            ),
            _RichSectionsSummary(page: page),
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
              MediaQuery.of(context).padding.bottom + AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: const Border(
                top: BorderSide(color: AppColors.slateBorder),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Read-only summary of the rich JSON sections we don't surface in the
/// mobile form. Reads counts from `page.raw` so the admin knows their
/// content is preserved on save.
class _RichSectionsSummary extends StatelessWidget {
  const _RichSectionsSummary({required this.page});
  final api.LandingPage page;

  int _len(dynamic v) {
    if (v is List) return v.length;
    return 0;
  }

  bool _has(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final raw = page.raw;
    final entries = <(String, String)>[
      ('Features', '${_len(raw['features'])} item(s)'),
      ('Testimonials', '${_len(raw['testimonials'])} item(s)'),
      ('FAQ', '${_len(raw['faq'])} item(s)'),
      ('Problem points', '${_len(raw['problemPoints'] ?? raw['problem_points'])} item(s)'),
      ('How-it-works', '${_len(raw['howItWorks'] ?? raw['how_it_works'])} step(s)'),
      ('Products', '${_len(raw['products'])} pinned'),
      ('Custom shipping', _has(raw['customShipping'] ?? raw['custom_shipping']) ? 'enabled' : 'off'),
    ];

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Text('Edit on web admin',
                  style: AppTypography.bodyMd.copyWith(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'These rich sections stay editable on the web admin. Mobile '
            'preserves their content on save — nothing is lost.',
            style: AppTypography.bodySm
                .copyWith(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          for (final e in entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      e.$1,
                      style: AppTypography.bodySm.copyWith(
                          color: AppColors.outline,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.$2,
                      style: AppTypography.bodySm.copyWith(
                          color: AppColors.onBackground,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        border: Border.all(color: AppColors.slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.h3.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.4)),
          const SizedBox(height: AppSpacing.sm),
          ...children,
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
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
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
