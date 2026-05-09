import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/list_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coupon codes — list, create, toggle active, delete.
///
/// Mobile editing is intentionally limited to the most common admin actions:
/// create a new code, flip live/paused, or remove. Full PATCH editing of
/// existing coupons (re-pricing, changing min order, extending expiry) stays
/// on the web admin where the form is more comfortable. Most coupon work
/// in practice is "make a new one for this campaign" or "kill that expired
/// one" — exactly what the mobile UI supports.
///
/// Live: the `coupons` SSE channel (already bumped by the admin write
/// routes) refreshes the list when another admin saves.
class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncCoupons = ref.watch(couponsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Coupons',
          style: context.h3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New coupon',
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: _showNewCouponSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(couponsProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            ListSearchField(
              hint: 'Search by code...',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.md),
            asyncCoupons.when(
              data: (list) => _CouponsList(query: _query, items: list),
              loading: () => const ListSkeleton(),
              error: (e, _) => ListInlineError(
                message: describeListError(e, 'Could not load coupons'),
                onRetry: () => ref.invalidate(couponsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewCouponSheet() async {
    final created = await showModalBottomSheet<api.Coupon>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xLarge)),
      ),
      builder: (_) => const _NewCouponSheet(),
    );
    if (created != null && mounted) {
      ref.invalidate(couponsProvider);
      _toast('Created "${created.code}"');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class _CouponsList extends ConsumerWidget {
  const _CouponsList({required this.query, required this.items});
  final String query;
  final List<api.Coupon> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.trim().toLowerCase();
    final visible = q.isEmpty
        ? items
        : items.where((c) => c.code.toLowerCase().contains(q)).toList();

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(
            q.isEmpty
                ? 'No coupons yet. Tap + to create one.'
                : 'No coupons match "$query"',
            style: context.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final c in visible) ...[
          _CouponCard(coupon: c),
          const SizedBox(height: AppSpacing.sm + 4),
        ],
      ],
    );
  }
}

class _CouponCard extends ConsumerStatefulWidget {
  const _CouponCard({required this.coupon});
  final api.Coupon coupon;

  @override
  ConsumerState<_CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends ConsumerState<_CouponCard> {
  bool _busy = false;

  Future<void> _toggleActive() async {
    setState(() => _busy = true);
    try {
      await ref.read(akhiyanApiProvider).coupons.update(
        widget.coupon.id,
        {'isActive': !widget.coupon.isActive},
      );
      if (!mounted) return;
      ref.invalidate(couponsProvider);
    } catch (e) {
      if (!mounted) return;
      _toast(describeListError(e, 'Toggle failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this coupon?'),
        content: Text(
            '"${widget.coupon.code}" will stop working immediately. This '
            'cannot be undone.'),
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
    setState(() => _busy = true);
    try {
      await ref.read(akhiyanApiProvider).coupons.delete(widget.coupon.id);
      if (!mounted) return;
      ref.invalidate(couponsProvider);
    } catch (e) {
      if (!mounted) return;
      _toast(describeListError(e, 'Delete failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _valueLabel(api.Coupon c) =>
      c.type == 'percentage' ? '${c.value.toStringAsFixed(0)}%' : '৳${c.value.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final c = widget.coupon;
    final disabled = !c.isActive || c.isExpired;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          c.code,
                          style: context.h3.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onBackground,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (c.isExpired)
                          const _SmallPill(
                              label: 'EXPIRED',
                              bg: AppColors.errorContainer,
                              fg: AppColors.onErrorContainer),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_valueLabel(c)} off · min ৳${c.minOrderAmount.toStringAsFixed(0)}',
                      style: context.bodySm.copyWith(
                        color: AppColors.outline,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: c.code));
                  _toast('Copied "${c.code}"');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 4, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              children: [
                _MetaCol(
                    label: 'USED',
                    value: c.maxUses == null
                        ? '${c.usedCount}'
                        : '${c.usedCount} / ${c.maxUses}'),
                const SizedBox(width: AppSpacing.lg),
                _MetaCol(label: 'STARTS', value: _formatDate(c.startsAt)),
                const SizedBox(width: AppSpacing.lg),
                _MetaCol(label: 'EXPIRES', value: _formatDate(c.expiresAt)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: c.isActive,
                  onChanged: _busy ? null : (_) => _toggleActive(),
                  title: Text(
                    disabled ? 'Paused or expired' : 'Live',
                    style: context.bodySm.copyWith(
                      color: disabled
                          ? AppColors.outline
                          : AppColors.onBackground,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error),
                onPressed: _busy ? null : _confirmDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(
      {required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: context.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 9,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MetaCol extends StatelessWidget {
  const _MetaCol({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.caption.copyWith(
                color: AppColors.outline,
                fontSize: 9,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 1),
        Text(value,
            style: context.bodySm.copyWith(
                color: AppColors.onBackground,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─── New coupon sheet ───────────────────────────────────────────────────────

class _NewCouponSheet extends ConsumerStatefulWidget {
  const _NewCouponSheet();

  @override
  ConsumerState<_NewCouponSheet> createState() => _NewCouponSheetState();
}

class _NewCouponSheetState extends ConsumerState<_NewCouponSheet> {
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _minOrder = TextEditingController(text: '0');
  final _maxUses = TextEditingController();
  String _type = 'percentage';
  DateTime? _startsAt;
  DateTime? _expiresAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minOrder.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool starts}) async {
    final now = DateTime.now();
    final initial = (starts ? _startsAt : _expiresAt) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (starts) {
        _startsAt = picked;
      } else {
        _expiresAt = picked;
      }
    });
  }

  Future<void> _save() async {
    final code = _code.text.trim().toUpperCase();
    final value = double.tryParse(_value.text.trim());
    if (code.isEmpty) {
      setState(() => _error = 'Code is required');
      return;
    }
    if (value == null || value <= 0) {
      setState(() => _error = 'Value must be a positive number');
      return;
    }
    if (_type == 'percentage' && value > 100) {
      setState(() => _error = 'Percentage must be 100 or less');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await ref.read(akhiyanApiProvider).coupons.create(
            code: code,
            type: _type,
            value: value,
            minOrderAmount:
                double.tryParse(_minOrder.text.trim()) ?? 0,
            maxUses: int.tryParse(_maxUses.text.trim()),
            startsAt: _startsAt,
            expiresAt: _expiresAt,
          );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = describeListError(e, 'Could not create coupon');
      });
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Pick a date';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Coupon',
                style: context.h3
                    .copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Code (e.g. SUMMER10)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'percentage', child: Text('Percentage off')),
                DropdownMenuItem(
                    value: 'fixed', child: Text('Fixed amount off')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            TextField(
              controller: _value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _type == 'percentage'
                    ? 'Value (e.g. 10 for 10%)'
                    : 'Value in ৳',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            TextField(
              controller: _minOrder,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minimum order (৳)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            TextField(
              controller: _maxUses,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max uses (blank for unlimited)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(starts: true),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('Start: ${_fmt(_startsAt)}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(starts: false),
                    icon: const Icon(Icons.event, size: 16),
                    label: Text('Expires: ${_fmt(_expiresAt)}'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: context.bodySm
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
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
