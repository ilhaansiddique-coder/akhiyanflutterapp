import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/live_theme.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_drawer.dart';
import 'package:akhiyan_admin/src/core/widgets/coming_soon.dart';
import 'package:akhiyan_admin/src/core/widgets/notification_bell.dart';
import 'package:akhiyan_admin/src/core/widgets/page_loading_overlay.dart';
import 'package:akhiyan_admin/src/core/widgets/pagination_bar.dart';
import 'package:akhiyan_admin/src/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Unified Users screen. Merges customers (paginated, `/customers`) and staff
/// (single-fetch, `/staff`) into one filterable list. The tab UI used to live
/// here; it was replaced by a role-filter dropdown so admins can slice across
/// All / Customer / Staff / Admin from a single search box.
///
/// Pagination only applies when customers are visible (`all` and `customer`
/// filters). Staff is small enough to render in one shot — no pagination
/// needed for `staff` / `admin`.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

enum _RoleFilter { all, customer, staff, admin }

extension on _RoleFilter {
  String get label => switch (this) {
        _RoleFilter.all => 'All Roles',
        _RoleFilter.customer => 'Customer',
        _RoleFilter.staff => 'Staff',
        _RoleFilter.admin => 'Admin',
      };

  Color get dot => switch (this) {
        _RoleFilter.all => AppColors.outline,
        _RoleFilter.customer => AppColors.secondary,
        _RoleFilter.staff => AppColors.success,
        _RoleFilter.admin => AppColors.tertiary,
      };
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Page number the user just tapped that is currently being fetched.
  int? _loadingPage;

  _RoleFilter _filter = _RoleFilter.all;

  void _goToPage(int p) {
    setState(() => _loadingPage = p);
    ref.read(customersListProvider.notifier).goToPage(p);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Mutation handlers ──────────────────────────────────────────────────

  /// Customer edit/delete are not exposed by the backend's mobile API today —
  /// `CustomersApi` only provides list + detail. Tell the user honestly
  /// rather than pretend.
  void _onCustomerEdit(api.CustomerListItem c) {
    _toast("Customer edit isn't available on the mobile API yet");
  }

  void _onCustomerDelete(api.CustomerListItem c) {
    _toast("Customer delete isn't available on the mobile API yet");
  }

  /// Open the edit-staff dialog. On save we call `api.staff.update` and
  /// invalidate the list provider — SSE will also refresh it shortly after,
  /// but the local invalidate makes the UI feel instant.
  Future<void> _onStaffEdit(api.StaffMember member) async {
    final updated = await showDialog<api.StaffMember>(
      context: context,
      builder: (_) => _EditStaffDialog(member: member),
    );
    if (updated != null && mounted) {
      ref.invalidate(staffListProvider);
      _toast('Saved "${updated.name}"');
    }
  }

  /// Confirm-then-delete dialog. On confirm we call `api.staff.delete` and
  /// invalidate the staff list. Errors surface as a snackbar; the row stays
  /// visible until the next refetch returns without it.
  Future<void> _onStaffDelete(api.StaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this user?'),
        content: Text(
          '${member.name.isEmpty ? 'This account' : member.name} will lose '
          'admin access immediately. This cannot be undone.',
        ),
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
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(akhiyanApiProvider).staff.delete(member.id);
      if (!mounted) return;
      ref.invalidate(staffListProvider);
      _toast('Deleted "${member.name}"');
    } catch (e) {
      if (!mounted) return;
      _toast(_describeError(e, fallback: 'Could not delete user'));
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showCustomers =
        _filter == _RoleFilter.all || _filter == _RoleFilter.customer;
    final showStaff = _filter == _RoleFilter.all ||
        _filter == _RoleFilter.staff ||
        _filter == _RoleFilter.admin;

    final state = ref.watch(customersListProvider);
    final asyncStaff = ref.watch(staffListProvider);

    if (!state.loading && _loadingPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(customersListProvider).loading) {
          setState(() => _loadingPage = null);
        }
      });
    }

    // Only show the page-switch overlay when the user actually tapped a
    // pagination button. Background sync refreshes (SSE bump → refresh)
    // also flip `state.loading` true; without the `_loadingPage` gate, the
    // overlay appeared every time another admin or the storefront wrote.
    final isPageSwitching =
        showCustomers && _loadingPage != null && state.loading && state.items.isNotEmpty;

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
          const NotificationBell(),
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
        ],
      ),
      // FAB removed — the shell's centered + (Create menu) is now the
      // single create entry across the app. The "New User" item there
      // opens the same NewUserDialog this screen used to launch.
      body: RefreshIndicator(
        onRefresh: () async {
          if (showCustomers) {
            await ref.read(customersListProvider.notifier).refresh();
          }
          if (showStaff) {
            ref.invalidate(staffListProvider);
            await ref.read(staffListProvider.future).catchError((_) => <api.StaffMember>[]);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: isPageSwitching,
              child: AnimatedOpacity(
                opacity: isPageSwitching ? 0.6 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl + AppSpacing.lg,
                  ),
                  children: [
                    // Search + filter row.
                    Row(
                      children: [
                        Expanded(child: _searchField()),
                        const SizedBox(width: AppSpacing.sm),
                        _RoleFilterChip(
                          selected: _filter,
                          onChanged: (f) => setState(() => _filter = f),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Users',
                      style: AppTypography.h1.copyWith(
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onBackground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ..._buildBody(
                      showCustomers: showCustomers,
                      showStaff: showStaff,
                      customerState: state,
                      staffAsync: asyncStaff,
                    ),
                    if (showCustomers)
                      PaginationBar(
                        currentPage: state.currentPage,
                        totalPages: state.totalPages,
                        loadingPage: isPageSwitching ? _loadingPage : null,
                        onPageChanged: _goToPage,
                      ),
                  ],
                ),
              ),
            ),
            if (isPageSwitching)
              PageLoadingOverlay(
                targetPage: _loadingPage ?? state.currentPage,
              ),
          ],
        ),
      ),
    );
  }

  // ─── Body composition ───────────────────────────────────────────────────

  /// Returns the list-section children for the current filter. Order:
  /// staff (if visible) first, then customers (if visible). Loading and
  /// error states bubble up inline so they replace just their slice rather
  /// than blanking the whole screen.
  List<Widget> _buildBody({
    required bool showCustomers,
    required bool showStaff,
    required PagedListState<api.CustomerListItem> customerState,
    required AsyncValue<List<api.StaffMember>> staffAsync,
  }) {
    final children = <Widget>[];

    // ─── Staff slice ───
    if (showStaff) {
      children.addAll(_staffSlice(staffAsync));
    }

    // Spacer between slices when both visible and both have content.
    final bothVisible = showStaff && showCustomers;

    // ─── Customer slice ───
    if (showCustomers) {
      if (bothVisible) {
        children.add(const SizedBox(height: AppSpacing.md));
      }
      children.addAll(_customerSlice(customerState));
    }

    if (children.isEmpty) {
      children.add(_emptyMessage(_query.isEmpty
          ? 'No users yet'
          : 'No users match "$_query"'));
    }

    return children;
  }

  List<Widget> _staffSlice(AsyncValue<List<api.StaffMember>> async) {
    return [
      async.when(
        loading: () => const Column(
          children: [
            _CustomerCardSkeleton(),
            SizedBox(height: AppSpacing.sm),
            _CustomerCardSkeleton(),
          ],
        ),
        error: (e, _) {
          // /staff isn't deployed everywhere yet — surface a friendly note
          // instead of a red error so the customers slice can still render.
          if (e is api.ApiException && e.isNotFound) {
            return const SizedBox.shrink();
          }
          return _inlineError(
            _describeError(e, fallback: 'Could not load staff'),
            onRetry: () => ref.invalidate(staffListProvider),
          );
        },
        data: (all) {
          final filtered = _filterStaff(all);
          if (filtered.isEmpty) {
            // Stay quiet when filter is "all" and there happens to be no
            // staff — the customer list still has content to show.
            if (_filter == _RoleFilter.all) return const SizedBox.shrink();
            return _emptyMessage(_query.isEmpty
                ? 'No ${_filter.label.toLowerCase()} accounts yet'
                : 'No matches for "$_query"');
          }
          return Column(
            children: [
              for (final s in filtered) ...[
                _StaffCard(
                  member: s,
                  onEdit: () => _onStaffEdit(s),
                  onDelete: () => _onStaffDelete(s),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
              ],
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _customerSlice(PagedListState<api.CustomerListItem> state) {
    if (state.loading && state.items.isEmpty) {
      return [
        for (int i = 0; i < 6; i++) ...const [
          _CustomerCardSkeleton(),
          SizedBox(height: AppSpacing.sm),
        ],
      ];
    }

    if (state.error != null && state.items.isEmpty) {
      final e = state.error!;
      if (e is api.ApiException && e.isNotFound) {
        return [comingSoonBody('Customers')];
      }
      return [
        _inlineError(
          _describeError(e, fallback: 'Could not load customers'),
          onRetry: () => ref.read(customersListProvider.notifier).refresh(),
        ),
      ];
    }

    final visible = state.items.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          (c.email ?? '').toLowerCase().contains(q) ||
          (c.phone ?? '').toLowerCase().contains(q);
    }).toList();

    if (visible.isEmpty) {
      // Don't dominate the screen with an empty state when the staff slice
      // already rendered something — return nothing instead.
      if (_filter == _RoleFilter.all) return const [];
      return [
        _emptyMessage(_query.isEmpty
            ? 'No customers yet'
            : 'No customers match "$_query"'),
      ];
    }

    return [
      for (final c in visible) ...[
        _CustomerCard(
          customer: c,
          onTap: () => context.push('/customers/${c.id}'),
          onEdit: () => _onCustomerEdit(c),
          onDelete: () => _onCustomerDelete(c),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
      ],
    ];
  }

  /// Apply the current role filter + search query to the staff list. Maps
  /// 'admin' / 'super_admin' to the Admin filter and everything else
  /// (manager, staff, …) to Staff. The 'all' / 'customer' filters either
  /// pass everyone through or hide staff entirely.
  List<api.StaffMember> _filterStaff(List<api.StaffMember> all) {
    Iterable<api.StaffMember> rows = all;

    switch (_filter) {
      case _RoleFilter.customer:
        return const [];
      case _RoleFilter.admin:
        rows = rows.where((s) {
          final r = s.role.toLowerCase();
          return r == 'admin' || r == 'super_admin' || r == 'superadmin';
        });
      case _RoleFilter.staff:
        rows = rows.where((s) {
          final r = s.role.toLowerCase();
          return r != 'admin' && r != 'super_admin' && r != 'superadmin';
        });
      case _RoleFilter.all:
        break;
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      rows = rows.where((s) =>
          s.name.toLowerCase().contains(q) ||
          (s.email ?? '').toLowerCase().contains(q) ||
          (s.phone ?? '').toLowerCase().contains(q) ||
          s.role.toLowerCase().contains(q));
    }

    return rows.toList();
  }

  // ─── Pieces ─────────────────────────────────────────────────────────────

  Widget _searchField() {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Search by name, email or phone...',
          prefixIcon: const Icon(
            Icons.search_rounded,
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
          hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.slateBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.slateBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide(color: primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _emptyMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Text(
          text,
          style: AppTypography.bodyMd
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _inlineError(String text, {required VoidCallback onRetry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

}

// ─── Helpers ────────────────────────────────────────────────────────────────

String _describeError(Object e, {String fallback = 'Something went wrong'}) {
  if (e is api.ApiException) return e.message;
  if (e is api.NetworkException) return 'No internet connection';
  return fallback;
}

/// Stable avatar palette derived from the user id so two renders of the
/// same row always pick the same colour.
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

String _formatStaffRole(String role) {
  switch (role.toLowerCase()) {
    case 'super_admin':
    case 'superadmin':
      return 'Super Admin';
    case 'admin':
      return 'Admin';
    case 'staff':
      return 'Staff';
    case 'manager':
      return 'Manager';
  }
  if (role.isEmpty) return 'Staff';
  return role
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) =>
          w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

// ─── Role filter dropdown ─────────────────────────────────────────────────

class _RoleFilterChip extends StatelessWidget {
  const _RoleFilterChip({required this.selected, required this.onChanged});
  final _RoleFilter selected;
  final ValueChanged<_RoleFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_RoleFilter>(
      tooltip: 'Filter by role',
      initialValue: selected,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      itemBuilder: (ctx) => [
        for (final f in _RoleFilter.values)
          PopupMenuItem<_RoleFilter>(
            value: f,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: f.dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(f.label),
                const Spacer(),
                if (f == selected)
                  const Icon(Icons.check, size: 16, color: AppColors.primary),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 2,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.slateBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.label,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Customer card ─────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final api.CustomerListItem customer;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xLarge),
      child: InkWell(
        onTap: onTap,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: avatar + identity + trailing actions group.
              Row(
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
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _TrailingActions(
                    pill: const _RolePill(
                      label: 'Customer',
                    ),
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              // Bottom: order/spend metadata (separated by a hairline).
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
                      value: '৳ ${_formatTaka(customer.totalSpent)}',
                      valueColor: AppColors.primary,
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

// ─── Staff card ────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.member,
    required this.onEdit,
    required this.onDelete,
  });
  final api.StaffMember member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = _avatarPalette(member.id);
    final initials = _initialsOf(member.name);
    final roleLabel = _formatStaffRole(member.role);
    final r = member.role.toLowerCase();
    final isAdmin = r == 'admin' || r == 'super_admin' || r == 'superadmin';
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
      child: Row(
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
                  member.name.isEmpty ? 'Unknown' : member.name,
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
                  member.email ?? member.phone ?? '—',
                  style: AppTypography.bodySm.copyWith(
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
          _TrailingActions(
            pill: _RolePill(
              label: roleLabel,
              tone: isAdmin ? _PillTone.admin : _PillTone.staff,
            ),
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

// ─── Role pill ─────────────────────────────────────────────────────────────

/// Role pill tone. Each role has its own dedicated colour pair pulled from
/// the live theme — `role_customer_bg/fg` for Customer, `role_admin_bg/fg`
/// for Admin, `role_staff_bg/fg` for Staff. When the backend customizer
/// exposes these keys, admins can recolour role badges without an app
/// release; until then we fall back to the design defaults below
/// (slate-blue for Customer, lavender for Admin, success-green for Staff)
/// — these match the reference admin dashboard and stay distinct from the
/// brand primary so role tags don't get lost when the brand colour
/// changes.
enum _PillTone { customer, admin, staff }

/// Hardcoded fallbacks. Picked to read clearly on white and to feel
/// independent of the brand primary so a customizer change to the brand
/// orange doesn't drag role pills along with it.
const _Color _kCustomerBg = _Color(0xFFDBEAFE); // blue-100
const _Color _kCustomerFg = _Color(0xFF1D4ED8); // blue-700
const _Color _kAdminBg = _Color(0xFFEDE9FE); // purple-100
const _Color _kAdminFg = _Color(0xFF6D28D9); // purple-700

typedef _Color = Color;

class _RolePill extends ConsumerWidget {
  const _RolePill({required this.label, this.tone = _PillTone.customer});
  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the live theme; the colors map carries arbitrary keys the
    // backend customizer can expose. We tolerate the AsyncValue being in
    // loading or error state by falling back to defaults — the rest of
    // the app handles theme errors via FriendlyErrorWidget.
    final liveTheme = ref.watch(liveThemeProvider).value;
    final colors = liveTheme?.colors ?? const <String, String>{};

    Color resolve(String key, Color fallback) =>
        _parseHex(colors[key]) ?? fallback;

    final (bg, fg) = switch (tone) {
      _PillTone.customer => (
          resolve('role_customer_bg', _kCustomerBg),
          resolve('role_customer_fg', _kCustomerFg),
        ),
      _PillTone.admin => (
          resolve('role_admin_bg', _kAdminBg),
          resolve('role_admin_fg', _kAdminFg),
        ),
      _PillTone.staff => (
          resolve('role_staff_bg', AppColors.successContainer),
          resolve('role_staff_fg', AppColors.onSuccessContainer),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.slateBorder),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// Convert `#rrggbb` / `#rrggbbaa` to a Color, or null on malformed input.
/// Local copy so [_RolePill] doesn't reach into the LiveTheme private API.
Color? _parseHex(String? hex) {
  if (hex == null) return null;
  final s = hex.trim().replaceFirst('#', '');
  if (s.length != 6 && s.length != 8) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  return s.length == 6 ? Color(0xFF000000 | value) : Color(value);
}

// ─── Trailing actions group (pill + edit + delete) ────────────────────────

/// Right-side action group used by every user row. Keeps the role pill,
/// edit chip, and delete chip on one line with even gaps so customers and
/// staff cards read identically.
class _TrailingActions extends StatelessWidget {
  const _TrailingActions({
    required this.pill,
    required this.onEdit,
    required this.onDelete,
  });

  final Widget pill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill,
        const SizedBox(width: AppSpacing.sm),
        _RowActions(onEdit: onEdit, onDelete: onDelete),
      ],
    );
  }
}

// ─── Meta column (ORDERS / SPEND) ─────────────────────────────────────────

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

// ─── Skeleton (first-load placeholder) ─────────────────────────────────────

class _CustomerCardSkeleton extends StatelessWidget {
  const _CustomerCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
                  SkeletonText(width: 160),
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

// ─── Row actions (edit / delete) ──────────────────────────────────────────

/// Pair of compact icon buttons attached to every user row. Replaces the
/// previous "more" overflow menu — fewer taps to reach the actions and
/// matches the reference admin dashboard.
class _RowActions extends StatelessWidget {
  const _RowActions({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionChip(
          tooltip: 'Edit',
          icon: Icons.edit_outlined,
          color: primary,
          onPressed: onEdit,
        ),
        const SizedBox(width: 6),
        _ActionChip(
          tooltip: 'Delete',
          icon: Icons.delete_outline_rounded,
          color: AppColors.error,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      shape: const CircleBorder(side: BorderSide(color: AppColors.slateBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

// ─── Edit staff dialog ────────────────────────────────────────────────────

/// Inline edit form for a staff member. Fields mirror what the backend
/// `PATCH /staff/:id` endpoint accepts — name, phone, role. Email is
/// read-only because the backend doesn't allow changing it post-creation.
///
/// Pops the updated `StaffMember` on success, or `null` on cancel.
class _EditStaffDialog extends ConsumerStatefulWidget {
  const _EditStaffDialog({required this.member});
  final api.StaffMember member;

  @override
  ConsumerState<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends ConsumerState<_EditStaffDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late String _role;
  bool _saving = false;
  String? _error;

  static const _roleOptions = <(String, String)>[
    ('staff', 'Staff'),
    ('manager', 'Manager'),
    ('admin', 'Admin'),
    ('super_admin', 'Super Admin'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.member.name);
    _phoneCtrl = TextEditingController(text: widget.member.phone ?? '');
    final r = widget.member.role.toLowerCase();
    _role = _roleOptions.any((o) => o.$1 == r) ? r : 'staff';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ref.read(akhiyanApiProvider).staff.update(
            widget.member.id,
            name: name,
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            role: _role,
          );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _describeError(e, fallback: 'Could not save changes');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: TextEditingController(text: widget.member.email ?? ''),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Email (read-only)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final (value, label) in _roleOptions)
                  DropdownMenuItem(value: value, child: Text(label)),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _role = v ?? _role),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─── New user dialog ──────────────────────────────────────────────────────

/// Create-staff form. Mirrors `POST /staff` — name, email, password are
/// required by the backend; phone and role are optional. On success it
/// pops the freshly-created [api.StaffMember] so the caller can refresh
/// the list. Customer signup is intentionally NOT here: the mobile API
/// has no `POST /customers` route (customer accounts come from the
/// storefront), so trying to create one would 404.
class NewUserDialog extends ConsumerStatefulWidget {
  const NewUserDialog({super.key});

  @override
  ConsumerState<NewUserDialog> createState() => NewUserDialogState();
}

class NewUserDialogState extends ConsumerState<NewUserDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  String _role = 'staff';
  bool _saving = false;
  String? _error;

  static const _roleOptions = <(String, String)>[
    ('staff', 'Staff'),
    ('manager', 'Manager'),
    ('admin', 'Admin'),
    ('super_admin', 'Super Admin'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Valid email is required');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await ref.read(akhiyanApiProvider).staff.create(
            name: name,
            email: email,
            password: password,
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            role: _role,
          );
      if (!mounted) return;
      // Refresh the list ourselves so the dialog works the same whether
      // it's launched from the global Create menu or the Users screen —
      // callers don't have to remember to invalidate.
      ref.invalidate(staffListProvider);
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _describeError(e, fallback: 'Could not create user');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New User'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _password,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Password (min 6 chars)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final (value, label) in _roleOptions)
                  DropdownMenuItem(value: value, child: Text(label)),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _role = v ?? _role),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
