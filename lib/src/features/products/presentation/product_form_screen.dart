import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/product.dart';

/// Combined Add/Edit product form. Merged from `add_product_2/code.html`
/// (sections: images, basic info, pricing, stock, variants, status, SEO)
/// and the prior Flutter port (3-state status, add/edit dual mode,
/// validation). Primary CTAs live in a sticky bottom bar — "Save as Draft"
/// + "Publish" in add mode, "Delete" + "Save Changes" in edit mode.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({this.productId, super.key});

  final String? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _brand;
  late final TextEditingController _price;
  late final TextEditingController _salePrice;
  late final TextEditingController _stock;
  late final TextEditingController _sku;
  late final TextEditingController _metaTitle;
  late final TextEditingController _metaDescription;
  String _category = 'Footwear';
  ProductStatus _status = ProductStatus.draft;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    // TODO: when editing, fetch the live product via
    // `ref.read(akhiyanApiProvider).products.detail(int.parse(widget.productId!))`
    // and prefill controllers from that response.
    _name = TextEditingController();
    _description = TextEditingController();
    _brand = TextEditingController();
    _price = TextEditingController();
    _salePrice = TextEditingController();
    _stock = TextEditingController();
    _sku = TextEditingController(text: widget.productId ?? '');
    _metaTitle = TextEditingController();
    _metaDescription = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _brand.dispose();
    _price.dispose();
    _salePrice.dispose();
    _stock.dispose();
    _sku.dispose();
    _metaTitle.dispose();
    _metaDescription.dispose();
    super.dispose();
  }

  void _save({ProductStatus? overrideStatus}) {
    if (!_formKey.currentState!.validate()) return;
    final finalStatus = overrideStatus ?? _status;
    final message = _isEdit
        ? 'Product updated (mock)'
        : finalStatus == ProductStatus.active
        ? 'Product published (mock)'
        : 'Product saved as draft (mock)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
      ),
    );
    context.pop();
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text(
          'This will remove the product from the catalog. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Product deleted (mock)')),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close, color: AppColors.onSurface),
        ),
        title: Text(
          _isEdit ? 'Edit Product' : 'Add Product',
          style: AppTypography.h3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
          ),
          children: [
            const _ImagesSection(),
            const SizedBox(height: AppSpacing.lg),
            _BasicInfoSection(
              name: _name,
              description: _description,
              brand: _brand,
              category: _category,
              onCategoryChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: AppSpacing.md),
            _PricingSection(price: _price, salePrice: _salePrice),
            const SizedBox(height: AppSpacing.md),
            _StockSection(stock: _stock, sku: _sku),
            const SizedBox(height: AppSpacing.md),
            const _VariantsSection(),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.md),
              _StatusSection(
                status: _status,
                onChanged: (s) => setState(() => _status = s),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _SeoSection(
              metaTitle: _metaTitle,
              metaDescription: _metaDescription,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ActionBar(
        isEdit: _isEdit,
        onSaveDraft: () => _save(overrideStatus: ProductStatus.draft),
        onPublish: () => _save(overrideStatus: ProductStatus.active),
        onSave: _save,
        onDelete: _confirmDelete,
      ),
    );
  }
}

// ─── Shared form helpers ─────────────────────────────────────────────────

/// Field label rendered above each input — matches the mockup's
/// `label-md` slate-700 hint above each control.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppTypography.bodySm.copyWith(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  String? hint,
  String? prefixText,
}) {
  const radius = AppRadius.medium;
  return InputDecoration(
    hintText: hint,
    prefixText: prefixText,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 12,
    ),
    filled: true,
    fillColor: AppColors.surfaceContainerLowest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: AppColors.borderSubtle),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: AppColors.borderSubtle),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.h3.copyWith(fontSize: 16),
    );
  }
}

// ─── Product Images section (no enclosing card) ──────────────────────────

class _ImagesSection extends StatelessWidget {
  const _ImagesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PRODUCT IMAGES',
                style: AppTypography.caption.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  fontSize: 11,
                ),
              ),
              Text(
                'Up to 5 images',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.outline,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 128,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              _AddImageTile(),
              SizedBox(width: AppSpacing.gutter),
              _ExistingImageTile(filled: true),
              SizedBox(width: AppSpacing.gutter),
              _ExistingImageTile(filled: false),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: const DottedBorderBox(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 32,
                  color: AppColors.onSurfaceVariant,
                ),
                SizedBox(height: 4),
                Text(
                  'Add Image',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed-border box drawn via [CustomPaint]. Flutter has no built-in
/// dashed border, so we paint it manually around the child.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.outlineVariant
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.large),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashedPath(path, dashLength: 6, gapLength: 4);
    canvas.drawPath(dashed, paint);
  }

  Path _dashedPath(Path source, {required double dashLength, required double gapLength}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        dest.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + gapLength;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_DottedBorderPainter oldDelegate) => false;
}

/// Placeholder image tile for an "uploaded" image. Has an X delete badge
/// overlaid in the top-right corner. The `filled` variant shows a solid
/// gray placeholder; the other shows a subtler tone (stand-in for a still-
/// uploading image — without the spinner overlay since we have no async
/// work to drive it from in this mock form).
class _ExistingImageTile extends StatelessWidget {
  const _ExistingImageTile({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: filled
                    ? AppColors.surfaceContainerHigh
                    : AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
              child: const Icon(
                Icons.image_outlined,
                size: 36,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: AppColors.surfaceContainerLowest,
              shape: const CircleBorder(),
              elevation: 1,
              child: InkWell(
                onTap: () {},
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(Icons.close, size: 14, color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Basic Information section ───────────────────────────────────────────

class _BasicInfoSection extends StatelessWidget {
  const _BasicInfoSection({
    required this.name,
    required this.description,
    required this.brand,
    required this.category,
    required this.onCategoryChanged,
  });

  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController brand;
  final String category;
  final ValueChanged<String> onCategoryChanged;

  static const _categories = ['Footwear', 'Apparel', 'Accessories'];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Basic Information'),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Product Name'),
          TextFormField(
            controller: name,
            decoration: _inputDecoration(
              hint: 'e.g. Premium Leather Sneakers',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Description'),
          TextFormField(
            controller: description,
            maxLines: 4,
            decoration: _inputDecoration(
              hint: 'Detailed product description...',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Category'),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      items: [
                        for (final c in _categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) {
                        if (v != null) onCategoryChanged(v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Brand'),
                    TextFormField(
                      controller: brand,
                      decoration: _inputDecoration(hint: 'Brand name'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pricing section ─────────────────────────────────────────────────────

class _PricingSection extends StatelessWidget {
  const _PricingSection({required this.price, required this.salePrice});

  final TextEditingController price;
  final TextEditingController salePrice;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Pricing'),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Regular Price'),
                    TextFormField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        hint: '0.00',
                        prefixText: '৳ ',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (num.tryParse(v) == null) return 'Number';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Sale Price'),
                    TextFormField(
                      controller: salePrice,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        hint: '0.00',
                        prefixText: '৳ ',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stock Control section ───────────────────────────────────────────────

class _StockSection extends StatelessWidget {
  const _StockSection({required this.stock, required this.sku});

  final TextEditingController stock;
  final TextEditingController sku;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Stock Control'),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Stock Quantity'),
                    TextFormField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(hint: '0'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('SKU'),
                    TextFormField(
                      controller: sku,
                      decoration: _inputDecoration(hint: 'SKU-123'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Product Variants section ────────────────────────────────────────────

class _VariantsSection extends StatefulWidget {
  const _VariantsSection();

  @override
  State<_VariantsSection> createState() => _VariantsSectionState();
}

class _VariantsSectionState extends State<_VariantsSection> {
  // Mock single variant entry — backed by local list since the Product
  // domain doesn't model variants yet.
  final _variants = <({String size, String color})>[
    (size: 'US 10', color: 'Red'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.layers_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              const _SectionTitle('Product Variants'),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() {
                  _variants.add((size: 'US ?', color: 'Color'));
                }),
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _variants.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  _variantPair('Size', _variants[i].size),
                  const SizedBox(width: AppSpacing.md),
                  _variantPair('Color', _variants[i].color),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _variants.removeAt(i)),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            if (i < _variants.length - 1) const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => setState(() {
              _variants.add((size: 'US ?', color: 'Color'));
            }),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add variant'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _variantPair(String label, String value) {
    return Row(
      children: [
        Text(
          '$label:',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Status section (edit-only) ──────────────────────────────────────────

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.status, required this.onChanged});

  final ProductStatus status;
  final ValueChanged<ProductStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Active Status'),
          const SizedBox(height: 4),
          Text(
            'Make this product visible to customers',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<ProductStatus>(
            segments: const [
              ButtonSegment(
                value: ProductStatus.active,
                label: Text('Active'),
                icon: Icon(Icons.check_circle_outline),
              ),
              ButtonSegment(
                value: ProductStatus.draft,
                label: Text('Draft'),
                icon: Icon(Icons.edit_outlined),
              ),
              ButtonSegment(
                value: ProductStatus.archived,
                label: Text('Archived'),
                icon: Icon(Icons.archive_outlined),
              ),
            ],
            selected: {status},
            onSelectionChanged: (s) => onChanged(s.first),
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }
}

// ─── Search Engine Listing section ───────────────────────────────────────

class _SeoSection extends StatelessWidget {
  const _SeoSection({
    required this.metaTitle,
    required this.metaDescription,
  });

  final TextEditingController metaTitle;
  final TextEditingController metaDescription;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.search, color: AppColors.onSurfaceVariant),
              SizedBox(width: AppSpacing.sm),
              _SectionTitle('Search Engine Listing'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Meta Title'),
          TextFormField(
            controller: metaTitle,
            decoration: _inputDecoration(hint: 'Search engine title...'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Meta Description'),
          TextFormField(
            controller: metaDescription,
            maxLines: 2,
            decoration: _inputDecoration(
              hint: 'Brief summary for search results...',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sticky bottom action bar ────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isEdit,
    required this.onSaveDraft,
    required this.onPublish,
    required this.onSave,
    required this.onDelete,
  });

  final bool isEdit;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: isEdit ? onDelete : onSaveDraft,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isEdit
                      ? AppColors.error
                      : AppColors.onSurface,
                  side: BorderSide(
                    color: isEdit ? AppColors.error : AppColors.borderSubtle,
                  ),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isEdit ? 'Delete' : 'Save Draft',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: isEdit ? onSave : onPublish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isEdit ? 'Save Changes' : 'Publish Product',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
