import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/customers/presentation/customers_screen.dart'
    show NewUserDialog;
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Open the global "Create" bottom sheet. Wired to the centered + button
/// in [AppShell]'s bottom nav so it's reachable from every screen, and
/// the dashboard FAB used to call it directly before the FAB moved into
/// the nav bar.
///
/// Bottom sheet over a popup menu was the right call: tappable targets
/// need to be comfortable on a phone, and the sheet gives us room for
/// a description per item without crowding.
void openCreateMenu(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xLarge)),
    ),
    builder: (_) => const _CreateMenuSheet(),
  );
}

class _CreateMenuSheet extends StatelessWidget {
  const _CreateMenuSheet();

  @override
  Widget build(BuildContext context) {
    final items = <_CreateItem>[
      _CreateItem(
        icon: Icons.shopping_cart_outlined,
        label: 'New Order',
        subtitle: 'Log a phone-in or in-store order',
        onTap: (ctx) {
          Navigator.of(ctx).pop();
          context.push('/orders/new');
        },
      ),
      _CreateItem(
        icon: Icons.add_box_outlined,
        label: 'New Product',
        subtitle: 'Add a product to your catalog',
        onTap: (ctx) {
          Navigator.of(ctx).pop();
          context.push('/products/new');
        },
      ),
      _CreateItem(
        icon: Icons.person_add_alt_1,
        label: 'New User',
        subtitle: 'Invite a staff or admin account',
        // Open the dialog directly instead of navigating first — the
        // shell's docked FAB is the unified create entry, so admins
        // shouldn't have to land on /customers and find another button.
        onTap: (ctx) async {
          Navigator.of(ctx).pop();
          await showDialog<void>(
            context: context,
            builder: (_) => const NewUserDialog(),
          );
        },
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.md),
              child: Text(
                'Create',
                style: AppTypography.h2.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final item in items) ...[
              _CreateTile(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateItem {
  const _CreateItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final void Function(BuildContext sheetCtx) onTap;
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.item});
  final _CreateItem item;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.xLarge),
      child: InkWell(
        onTap: () => item.onTap(context),
        borderRadius: BorderRadius.circular(AppRadius.xLarge),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xLarge),
            border: Border.all(color: AppColors.slateBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Icon(item.icon, color: primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
