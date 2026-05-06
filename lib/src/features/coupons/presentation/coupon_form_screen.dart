import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class CouponFormScreen extends StatefulWidget {
  const CouponFormScreen({super.key});

  @override
  State<CouponFormScreen> createState() => _CouponFormScreenState();
}

class _CouponFormScreenState extends State<CouponFormScreen> {
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _minOrder = TextEditingController();
  String _type = 'percent';

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Text('New Coupon'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coupon created (mock)')),
              );
              context.pop();
            },
            child: const Text('Create'),
          ),
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.home_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _Section(
            title: 'Code',
            child: TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'FESTIVE10',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Discount Type',
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'percent', label: Text('Percent')),
                ButtonSegment(value: 'fixed', label: Text('Fixed Amount')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Value',
            child: TextFormField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: _type == 'fixed' ? '৳ ' : null,
                suffixText: _type == 'percent' ? '%' : null,
                hintText: '0',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Minimum Order',
            child: TextFormField(
              controller: _minOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '৳ ',
                hintText: '0',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Validity',
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.event, size: 18),
                    label: const Text('Start Date'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.event, size: 18),
                    label: const Text('End Date'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 11,
              )),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
