import 'dart:async';
import 'dart:convert';

import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/notification_bell.dart';
import 'package:akhiyan_admin/src/core/widgets/states/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Manual order entry. Admin captures customer details + line items and
/// posts to `POST /api/v1/m/orders`. The backend persists, computes the
/// canonical totals, and emits a `bumpVersion('orders')` so the
/// storefront, web admin, and this app's orders list all refresh within
/// a second of save (per the SSE pattern).
///
/// This is for in-store / phone-in / WhatsApp orders that don't flow
/// through the storefront cart. Online checkouts continue to come from
/// the storefront — this form supplements them, not replaces them.
class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _zip = TextEditingController();
  final _shipping = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _notes = TextEditingController();
  String _paymentMethod = 'cod';

  /// Local line items. Each row holds a product reference + quantity.
  /// Price is captured at the moment of selection (snapshot of the
  /// listed price); admins can override before submit.
  final List<_LineItem> _items = [];

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _zip.dispose();
    _shipping.dispose();
    _discount.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0, (sum, it) => sum + (it.price * it.quantity));
  double get _shippingCost => double.tryParse(_shipping.text) ?? 0;
  double get _discountAmount => double.tryParse(_discount.text) ?? 0;
  double get _total => (_subtotal + _shippingCost - _discountAmount)
      .clamp(0, double.infinity)
      .toDouble();

  // ─── Add product flow ───────────────────────────────────────────────────

  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<_PickResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xLarge)),
      ),
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked == null || !mounted) return;
    // Stack the same product/variant as a separate line for now —
    // prevents accidental price overrides bleeding across rows. Admins
    // can delete + re-add if they want to merge.
    setState(() {
      _items.add(_LineItem(
        productId: picked.productId,
        productName: picked.productName,
        price: picked.price,
        quantity: 1,
        variantId: picked.variantId,
        variantLabel: picked.variantLabel,
      ));
    });
  }

  // ─── Submit ─────────────────────────────────────────────────────────────

  /// Submits the order **optimistically**: pops back to the previous
  /// screen immediately and runs the POST in the background.
  ///
  /// Trade-off: if the backend rejects the order (validation, server
  /// error), the form is already gone — the user gets a snackbar with
  /// the error and has to start over. This is acceptable because:
  ///   1. Client-side validation catches most issues before submit.
  ///   2. The happy path is dramatically faster (no waiting for the
  ///      POST round-trip; orders list refreshes via SSE within ~1s).
  ///   3. Admins re-enter rarely; staring at a spinner for every save
  ///      is a worse daily experience than the rare error reset.
  Future<void> _submit() async {
    // Re-entry guard: a fast double-tap on Save would otherwise call
    // pop() twice and fire two POSTs. Once true, this State will be
    // disposed before any code path could reset the flag.
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      _toast('Add at least one product');
      return;
    }
    _saving = true;

    // Capture all the values + the messenger BEFORE popping, because
    // once `context.pop()` runs the State is disposed and `context` is
    // no longer valid for showing snackbars.
    final api_ = ref.read(akhiyanApiProvider);
    final messenger = ScaffoldMessenger.of(context);
    final payload = (
      customerName: _name.text.trim(),
      customerPhone: _phone.text.trim(),
      customerEmail: _email.text.trim().isEmpty ? null : _email.text.trim(),
      customerAddress: _address.text.trim(),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      zipCode: _zip.text.trim().isEmpty ? null : _zip.text.trim(),
      items: [
        for (final it in _items)
          {
            'productId': it.productId,
            if (it.variantId != null) 'variantId': it.variantId,
            'quantity': it.quantity,
            'price': it.price,
          },
      ],
      shippingCost: _shippingCost,
      discount: _discountAmount,
      paymentMethod: _paymentMethod,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    // Pop FIRST — the user is back on the orders list within ~16ms.
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Saving order...'),
        duration: Duration(seconds: 60),
      ),
    );
    context.pop();

    // POST in background. Errors surface via the persistent snackbar.
    unawaited(() async {
      try {
        await api_.orders.create(
          customerName: payload.customerName,
          customerPhone: payload.customerPhone,
          customerEmail: payload.customerEmail,
          customerAddress: payload.customerAddress,
          city: payload.city,
          zipCode: payload.zipCode,
          items: payload.items,
          shippingCost: payload.shippingCost,
          discount: payload.discount,
          paymentMethod: payload.paymentMethod,
          notes: payload.notes,
        );
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Order created'),
              duration: Duration(seconds: 2),
            ),
          );
      } on api.ApiException catch (e) {
        messenger.hideCurrentSnackBar();
        final raw = e.raw;
        final pretty = raw == null
            ? e.message
            : const JsonEncoder.withIndent('  ').convert(raw);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              e.statusCode == 404
                  ? 'Order create endpoint not deployed yet on the backend'
                  : 'Order failed (HTTP ${e.statusCode}): ${e.message}',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                // Re-show the raw payload in a dialog rooted on whatever
                // screen the user has navigated to.
                final ctx = messenger.context;
                showDialog<void>(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    title: Text('HTTP ${e.statusCode}'),
                    content: SingleChildScrollView(
                      child: SelectableText(pretty),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      } catch (e) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not create order: $e'),
              backgroundColor: AppColors.error,
            ),
          );
      }
    }());
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Text('New Order'),
        actions: const [NotificationBell()],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          // Extra bottom space so the action buttons don't visually
          // collide with the shell's centered + FAB which sticks up from
          // the bottom nav. xl + sm clears the FAB notch comfortably.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl + AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
                  ),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          'Create  •  ৳${_total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          children: [
            _SectionCard(
              title: 'Customer',
              child: Column(
                children: [
                  _Field(controller: _name, label: 'Name', required: true),
                  const SizedBox(height: AppSpacing.md),
                  _Field(
                    controller: _phone,
                    label: 'Phone',
                    keyboardType: TextInputType.phone,
                    required: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Field(
                    controller: _email,
                    label: 'Email (optional)',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Field(
                    controller: _address,
                    label: 'Address',
                    required: true,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(controller: _city, label: 'City'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _Field(
                          controller: _zip,
                          label: 'ZIP',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Items',
              trailing: TextButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Product'),
              ),
              child: _items.isEmpty
                  ? Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: Text(
                          'No items yet — tap Add Product',
                          style: context.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < _items.length; i++) ...[
                          _LineItemRow(
                            item: _items[i],
                            onQuantityChanged: (q) =>
                                setState(() => _items[i].quantity = q),
                            onRemove: () =>
                                setState(() => _items.removeAt(i)),
                          ),
                          if (i < _items.length - 1)
                            const Divider(
                                height: AppSpacing.md, thickness: 0.5),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Pricing',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          controller: _shipping,
                          label: 'Shipping (৳)',
                          keyboardType: TextInputType.number,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _Field(
                          controller: _discount,
                          label: 'Discount (৳)',
                          keyboardType: TextInputType.number,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SummaryRow(label: 'Subtotal', value: _subtotal),
                  _SummaryRow(label: 'Shipping', value: _shippingCost),
                  _SummaryRow(
                      label: 'Discount', value: -_discountAmount),
                  const Divider(height: AppSpacing.md, thickness: 0.5),
                  _SummaryRow(label: 'Total', value: _total, emphasis: true),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Payment & Notes',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cod', child: Text('Cash on Delivery')),
                      DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                      DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(
                            () => _paymentMethod = v ?? _paymentMethod),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Field(
                    controller: _notes,
                    label: 'Notes (optional)',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Local types ────────────────────────────────────────────────────────────

class _LineItem {
  _LineItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.variantId,
    this.variantLabel,
  });
  final String productId;
  final String productName;
  final double price;
  final String? variantId;
  final String? variantLabel;
  int quantity;

  /// Pretty-printed name shown in the order summary. Folds the variant
  /// label into the product name when present so the cart row reads like
  /// "Maggi Tang/Top Set — Mint" without needing a second line.
  String get displayName =>
      variantLabel == null ? productName : '$productName — $variantLabel';
}

/// Result of the product picker. Either the base product (no variants
/// or admin chose the parent) or a specific variant row.
class _PickResult {
  const _PickResult({
    required this.productId,
    required this.productName,
    required this.price,
    this.variantId,
    this.variantLabel,
  });
  final String productId;
  final String productName;
  final double price;
  final String? variantId;
  final String? variantLabel;
}

// ─── UI pieces ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? trailing;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: context.h3.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.md - 2),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.required = false,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool required;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });
  final _LineItem item;
  final void Function(int q) onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName,
                style: context.bodyMd.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '৳${item.price.toStringAsFixed(0)} each',
                style: context.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _QuantityStepper(value: item.quantity, onChanged: onQuantityChanged),
        IconButton(
          tooltip: 'Remove',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.value, required this.onChanged});
  final int value;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slateBorder),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 16),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: context.bodyMd.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add, size: 16),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });
  final String label;
  final double value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final style = emphasis
        ? context.bodyMd.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          )
        : context.bodyMd.copyWith(color: AppColors.onSurface);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text('৳${value.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}

// ─── Product picker bottom sheet ────────────────────────────────────────────

/// Searchable product list. Reuses [productsListProvider] so the search
/// + pagination cache the rest of the app already populated comes for
/// free. Tapping a product pops it back to the order form.
class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  String _query = '';

  /// Product ids whose detail we've already kicked off a prefetch for.
  /// Prevents firing the same fetch on every rebuild (search keystrokes,
  /// scroll repaints, etc.).
  final Set<String> _prefetched = <String>{};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsListProvider);
    final filtered = _query.isEmpty
        ? state.items
        : state.items
            .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    // Eagerly fetch variant data for products that have variations so the
    // variant sheet pops open with no spinner. Cap at 8 to avoid hammering
    // the API when the list is long. Fire-and-forget; failures are silent
    // because the variant sheet handles the error path itself if the user
    // does end up tapping that product.
    var fired = 0;
    for (final p in filtered) {
      if (fired >= 8) break;
      if (!(p.hasVariations ?? false)) continue;
      if (_prefetched.contains(p.id)) continue;
      _prefetched.add(p.id);
      fired++;
      // Read .future so the FutureProvider actually resolves; ref.read
      // alone would only hand back the AsyncLoading state.
      ref.read(productDetailProvider(p.id).future).ignore();
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Text(
                'Add Product',
                style: context.h2.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: state.loading && state.items.isEmpty
                    ? const LoadingView()
                    : filtered.isEmpty
                        ? EmptyView(
                            message: _query.isEmpty
                                ? 'No products yet'
                                : 'No matches for "$_query"',
                            icon: Icons.search_off_rounded,
                          )
                        : _buildPickerList(scrollController, filtered),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension _PickerBuild on _ProductPickerSheetState {
  /// One row per product. Products with variations get a "Choose
  /// variant" hint + chevron — tapping fetches `/products/:id` (the
  /// list endpoint doesn't include variants) and shows a second sheet
  /// to pick the specific variant.
  Widget _buildPickerList(
    ScrollController scrollController,
    List<api.Product> products,
  ) {
    return ListView.separated(
      controller: scrollController,
      itemCount: products.length,
      separatorBuilder: (_, _) => const Divider(height: 0),
      itemBuilder: (_, i) {
        final p = products[i];
        final hasVariations = p.hasVariations ?? false;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _Thumb(image: p.image),
          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            hasVariations
                ? 'From ৳${p.price.toStringAsFixed(0)} • Choose variant'
                : '৳${p.price.toStringAsFixed(0)}',
          ),
          trailing: hasVariations
              ? const Icon(Icons.chevron_right_rounded,
                  color: AppColors.outline)
              : null,
          onTap: () async {
            if (!hasVariations) {
              Navigator.of(context).pop(_PickResult(
                productId: p.id,
                productName: p.name,
                price: p.price,
              ));
              return;
            }
            // Lazy-fetch variants — list endpoint doesn't include them.
            final picked = await showModalBottomSheet<_PickResult>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xLarge)),
              ),
              builder: (_) => _VariantPickerSheet(productId: p.id),
            );
            if (picked != null && mounted) {
              if (!context.mounted) return;
              Navigator.of(context).pop(picked);
            }
          },
        );
      },
    );
  }
}

/// Variant picker — opens after tapping a product with `hasVariations`.
/// Fetches `/products/:id` for the variant list (the cached list
/// endpoint omits them) and shows one row per variant. Pops the chosen
/// variant back up so the parent picker can return it to the order
/// form.
class _VariantPickerSheet extends ConsumerWidget {
  const _VariantPickerSheet({required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(productDetailProvider(productId));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Expanded(
                child: asyncDetail.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => const ErrorView(
                    message: 'Could not load variants',
                    icon: Icons.cloud_off,
                  ),
                  data: (p) {
                    final variants = p.variants ?? const [];
                    if (variants.isEmpty) {
                      return Center(
                        child: Text(
                          'No variants on this product',
                          style: context.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.md),
                          child: Row(
                            children: [
                              _Thumb(image: p.image),
                              const SizedBox(width: AppSpacing.md - 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: context.bodyMd.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${variants.length} variants',
                                      style: context.bodySm.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: variants.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 0),
                            itemBuilder: (_, i) {
                              final v = variants[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading:
                                    _Thumb(image: v.image ?? p.image),
                                title: Text(
                                  v.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '৳${v.price.toStringAsFixed(0)}',
                                ),
                                onTap: () =>
                                    Navigator.of(context).pop(_PickResult(
                                  productId: p.id,
                                  productName: p.name,
                                  price: v.price,
                                  variantId: v.id,
                                  variantLabel: v.label,
                                )),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Per-product detail provider, keyed by id. Auto-disposed: variants
// _productDetailProvider was promoted to `productDetailProvider` in
// `core/api/api_providers.dart` — kept app-wide and non-autoDispose so
// re-opening the variant sheet for the same product is instant. Stale
// data is handled by sync_invalidation invalidating the family on the
// backend `products` bump.

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image});
  final String image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        width: 44,
        height: 44,
        color: AppColors.surfaceContainer,
        child: image.isEmpty
            ? const Icon(Icons.image_outlined,
                color: AppColors.onSurfaceVariant)
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
