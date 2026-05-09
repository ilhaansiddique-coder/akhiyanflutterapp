import 'package:akhiyan_admin/api/akhiyan_api.dart' as api;
import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/errors/error_mapper.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/core/widgets/app_card.dart';
import 'package:akhiyan_admin/src/core/widgets/notification_bell.dart';
import 'package:akhiyan_admin/src/core/widgets/states/states.dart';
import 'package:akhiyan_admin/src/features/products/domain/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Combined Add/Edit product form. Wired to `/products` via
/// [akhiyanApiProvider]: GET on edit-mode init, POST on Publish/Save Draft,
/// PATCH on Save Changes, DELETE on Delete. Refreshes the products and
/// inventory lists on success.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({this.productId, super.key});

  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _salePrice;
  late final TextEditingController _stock;
  late final TextEditingController _sku;
  late final TextEditingController _metaTitle;
  late final TextEditingController _metaDescription;
  // Selected category / brand IDs. Null until the user picks one or the
  // product is loaded from the backend in edit mode.
  String? _categoryId;
  String? _brandId;
  ProductStatus _status = ProductStatus.draft;

  /// Live image URL list for this product. First entry maps to `image` on
  /// the backend; the full list maps to `images` (CSV). Order is
  /// preserved — index 0 is the primary image shown on cards/PDPs.
  /// Capped at [_kMaxImages] to match the backend `Up to 5 images` limit
  /// surfaced in the section header.
  final List<String> _imageUrls = [];
  bool _uploadingImage = false;

  bool _loading = false;
  bool _saving = false;
  Object? _loadError;

  static const _kMaxImages = 5;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _description = TextEditingController();
    _price = TextEditingController();
    _salePrice = TextEditingController();
    _stock = TextEditingController();
    _sku = TextEditingController();
    _metaTitle = TextEditingController();
    _metaDescription = TextEditingController();
    if (_isEdit) {
      _loading = true;
      Future.microtask(_loadExisting);
    }
  }

  Future<void> _loadExisting() async {
    try {
      final p =
          await ref.read(akhiyanApiProvider).products.detail(widget.productId!);
      if (!mounted) return;
      _name.text = p.name;
      _description.text = p.description ?? '';
      _stock.text = p.stock.toString();
      // Backend pricing: price = current selling price, originalPrice =
      // strikethrough. Mirror that in the form: if originalPrice exists, the
      // product is on sale → show originalPrice in "Regular" and price in
      // "Sale". Otherwise price goes in "Regular".
      if (p.originalPrice != null && p.originalPrice! > p.price) {
        _price.text = p.originalPrice!.toStringAsFixed(0);
        _salePrice.text = p.price.toStringAsFixed(0);
      } else {
        _price.text = p.price.toStringAsFixed(0);
      }
      // Hydrate the image gallery from the backend. Backend stores `image`
      // (primary) plus an optional comma-separated `images` for the rest;
      // we merge them into one ordered list, dropping duplicates so a
      // product whose primary URL also appears in `images` doesn't render
      // the same tile twice.
      final urls = <String>[];
      if (p.image.isNotEmpty) urls.add(p.image);
      final extras = p.images;
      if (extras != null && extras.isNotEmpty) {
        for (final raw in extras.split(',')) {
          final u = raw.trim();
          if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
        }
      }
      setState(() {
        _status = p.isActive ? ProductStatus.active : ProductStatus.draft;
        _categoryId = p.categoryId;
        _brandId = p.brandId;
        _imageUrls
          ..clear()
          ..addAll(urls);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _salePrice.dispose();
    _stock.dispose();
    _sku.dispose();
    _metaTitle.dispose();
    _metaDescription.dispose();
    super.dispose();
  }

  /// Builds the JSON body sent to POST /products and PATCH /products/:id.
  /// Only includes fields the form actually exposes. The image gallery is
  /// split into `image` (primary, index 0) + `images` (comma-separated
  /// rest) to match the backend schema.
  Map<String, dynamic> _buildPayload(ProductStatus finalStatus) {
    final regular = double.tryParse(_price.text.trim()) ?? 0;
    final saleStr = _salePrice.text.trim();
    final sale = saleStr.isEmpty ? null : double.tryParse(saleStr);
    final hasSale = sale != null && sale > 0 && sale < regular;
    final stock = int.tryParse(_stock.text.trim()) ?? 0;
    final desc = _description.text.trim();
    final primaryImage = _imageUrls.isEmpty ? null : _imageUrls.first;
    final extraImages =
        _imageUrls.length <= 1 ? '' : _imageUrls.skip(1).join(',');
    return {
      'name': _name.text.trim(),
      if (desc.isNotEmpty) 'description': desc,
      'price': hasSale ? sale : regular,
      if (hasSale) 'originalPrice': regular,
      'stock': stock,
      'isActive': finalStatus == ProductStatus.active,
      // Always send `image`/`images` even when empty so PATCHing an edit
      // can clear the gallery (sending nothing wouldn't overwrite).
      'image': primaryImage ?? '',
      'images': extraImages,
    };
  }

  /// Pick a single image from the device gallery, upload it, and append
  /// the returned URL to [_imageUrls]. Errors surface via snackbar; we
  /// never throw out of here so the form stays interactive.
  Future<void> _pickAndUploadImage() async {
    if (_uploadingImage) return;
    if (_imageUrls.length >= _kMaxImages) {
      _snack('Limit is $_kMaxImages images per product');
      return;
    }
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(
        source: ImageSource.gallery,
        // Cap dimensions before upload — keeps payloads small enough that
        // serverless upload routes don't time out on cellular networks.
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
    } catch (e) {
      _snack('Could not open gallery: $e');
      return;
    }
    if (file == null) return; // user cancelled

    setState(() => _uploadingImage = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await ref.read(akhiyanApiProvider).media.upload(
            bytes: bytes,
            filename: file.name,
          );
      if (!mounted) return;
      setState(() => _imageUrls.add(url));
    } on api.ApiException catch (e) {
      if (!mounted) return;
      _snack(e.statusCode == 404
          ? 'Image upload endpoint not deployed yet on the backend'
          : 'Upload failed: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _removeImageAt(int index) {
    setState(() => _imageUrls.removeAt(index));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save({ProductStatus? overrideStatus}) async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final finalStatus = overrideStatus ?? _status;
    setState(() => _saving = true);
    try {
      final payload = _buildPayload(finalStatus);
      if (_isEdit) {
        await ref
            .read(akhiyanApiProvider)
            .products
            .update(widget.productId!, payload);
      } else {
        await ref.read(akhiyanApiProvider).products.create(payload);
      }
      // No local invalidate — the backend's `bumpVersion('products')` reaches
      // us via SSE within ~1s and triggers a single refresh through
      // sync_invalidation. Doing it here too caused double-fetches (one
      // immediate, one on bump arrival) for every save.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit
              ? 'Product updated'
              : finalStatus == ProductStatus.active
                  ? 'Product published'
                  : 'Product saved as draft'),
          backgroundColor: AppColors.primary,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e, fallback: 'Could not save product')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _doDelete() async {
    setState(() => _saving = true);
    try {
      await ref.read(akhiyanApiProvider).products.delete(widget.productId!);
      // SSE 'products' bump refreshes the lists; see save handler comment.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e, fallback: 'Could not save product')),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
              _doDelete();
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
          onPressed: _saving ? null : () => context.pop(),
          icon: const Icon(Icons.close, color: AppColors.onSurface),
        ),
        title: Text(
          _isEdit ? 'Edit Product' : 'Add Product',
          style: context.h3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
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
      body: _loading
          ? const LoadingView()
          : _loadError != null
              ? ErrorView(
                  message: describeError(_loadError!, fallback: 'Could not load product'),
                  icon: Icons.cloud_off,
                  onRetry: () {
                    setState(() {
                      _loadError = null;
                      _loading = true;
                    });
                    _loadExisting();
                  },
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    children: [
                      _ImagesSection(
                        urls: _imageUrls,
                        uploading: _uploadingImage,
                        onAdd: _pickAndUploadImage,
                        onRemove: _removeImageAt,
                        max: _kMaxImages,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _BasicInfoSection(
                        name: _name,
                        description: _description,
                        categoryId: _categoryId,
                        brandId: _brandId,
                        onCategoryChanged: (id) =>
                            setState(() => _categoryId = id),
                        onBrandChanged: (id) =>
                            setState(() => _brandId = id),
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
        saving: _saving,
        onSaveDraft: () => _save(overrideStatus: ProductStatus.draft),
        onPublish: () => _save(overrideStatus: ProductStatus.active),
        onSave: _save,
        onDelete: _confirmDelete,
      ),
    );
  }
}

// ─── Shared form helpers ─────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: context.bodySm.copyWith(
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
      style: context.h3.copyWith(fontSize: 16),
    );
  }
}

// ─── Product Images section (no enclosing card) ──────────────────────────

class _ImagesSection extends StatelessWidget {
  const _ImagesSection({
    required this.urls,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
    required this.max,
  });

  final List<String> urls;
  final bool uploading;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final int max;

  @override
  Widget build(BuildContext context) {
    final canAddMore = urls.length < max;
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
                style: context.caption.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  fontSize: 11,
                ),
              ),
              Text(
                '${urls.length}/$max images',
                style: context.bodySm.copyWith(
                  color: AppColors.outline,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length + (canAddMore ? 1 : 0),
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppSpacing.gutter),
            itemBuilder: (context, i) {
              if (canAddMore && i == 0) {
                return _AddImageTile(uploading: uploading, onTap: onAdd);
              }
              final urlIndex = canAddMore ? i - 1 : i;
              return _ExistingImageTile(
                url: urls[urlIndex],
                isPrimary: urlIndex == 0,
                onRemove: () => onRemove(urlIndex),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.uploading, required this.onTap});
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: InkWell(
          onTap: uploading ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: DottedBorderBox(
            child: Center(
              child: uploading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Column(
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
      ),
    );
  }
}

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

  Path _dashedPath(Path source,
      {required double dashLength, required double gapLength}) {
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

/// Live image preview tile. Renders the hosted URL via [Image.network]
/// with a graceful fallback (broken-image glyph) if the host can't be
/// reached or the URL 404s — the form should never go red over a missing
/// thumbnail. Primary tile (index 0) gets a subtle badge so admins know
/// which image becomes the storefront card hero.
class _ExistingImageTile extends StatelessWidget {
  const _ExistingImageTile({
    required this.url,
    required this.isPrimary,
    required this.onRemove,
  });
  final String url;
  final bool isPrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.large),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.surfaceContainer,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          ),
          if (isPrimary)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Text(
                  'Primary',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
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
                onTap: onRemove,
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

/// Basic info card. Categories + brands are now fetched live from the
/// backend via [categoriesProvider] / [brandsProvider]; the previous
/// hardcoded `['Footwear', 'Apparel', 'Accessories']` list is gone. While
/// the lookup data is loading, both dropdowns render as disabled stubs so
/// the layout doesn't jump when the response arrives.
class _BasicInfoSection extends ConsumerWidget {
  const _BasicInfoSection({
    required this.name,
    required this.description,
    required this.categoryId,
    required this.brandId,
    required this.onCategoryChanged,
    required this.onBrandChanged,
  });

  final TextEditingController name;
  final TextEditingController description;
  final String? categoryId;
  final String? brandId;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onBrandChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final brands = ref.watch(brandsProvider);

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
                    _LookupDropdown(
                      value: categoryId,
                      hint: 'Select category',
                      itemsAsync: categories.whenData(
                        (list) => [
                          for (final c in list) (id: c.id, label: c.name),
                        ],
                      ),
                      onChanged: onCategoryChanged,
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
                    _LookupDropdown(
                      value: brandId,
                      hint: 'Select brand',
                      itemsAsync: brands.whenData(
                        (list) => [
                          for (final b in list) (id: b.id, label: b.name),
                        ],
                      ),
                      onChanged: onBrandChanged,
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

/// Shared dropdown that renders an async list of `(id, label)` pairs. Shows
/// a disabled placeholder while loading and an error label on failure so
/// the user understands why the dropdown isn't populated.
class _LookupDropdown extends StatelessWidget {
  const _LookupDropdown({
    required this.value,
    required this.hint,
    required this.itemsAsync,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final AsyncValue<List<({String id, String label})>> itemsAsync;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return itemsAsync.when(
      loading: () => DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: _inputDecoration(hint: 'Loading...'),
        items: const [],
        onChanged: null,
      ),
      error: (_, _) => DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: _inputDecoration(hint: 'Failed to load'),
        items: const [],
        onChanged: null,
      ),
      data: (items) {
        // If the current value isn't in the fetched list (e.g. a deleted
        // category referenced by an old product), fall back to null so the
        // dropdown doesn't throw.
        final safeValue =
            items.any((e) => e.id == value) ? value : null;
        return DropdownButtonFormField<String>(
          initialValue: safeValue,
          isExpanded: true,
          decoration: _inputDecoration(hint: hint),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item.id, child: Text(item.label)),
          ],
          onChanged: onChanged,
        );
      },
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
          style: context.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: context.bodySm.copyWith(
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
            style: context.bodySm.copyWith(
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
    required this.saving,
    required this.onSaveDraft,
    required this.onPublish,
    required this.onSave,
    required this.onDelete,
  });

  final bool isEdit;
  final bool saving;
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
                onPressed: saving ? null : (isEdit ? onDelete : onSaveDraft),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isEdit ? AppColors.error : AppColors.onSurface,
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
                    style: context.bodySm.copyWith(
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
                onPressed: saving ? null : (isEdit ? onSave : onPublish),
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
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                              AppColors.onPrimary),
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEdit ? 'Save Changes' : 'Publish Product',
                          style: context.bodySm.copyWith(
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
