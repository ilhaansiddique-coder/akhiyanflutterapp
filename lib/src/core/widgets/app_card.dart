import 'package:flutter/material.dart';

import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';

/// Elevated white card with optional border and a soft drop shadow.
/// The default surface for content blocks across the app — orders, products,
/// dashboard sections, order-detail panels.
///
/// Pass [onTap] to make the whole card tappable; `Material` + `InkWell`
/// are wired up so splash ripples render correctly on top of the surface.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding,
    this.onTap,
    this.clipBehavior = Clip.none,
    this.border,
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Border? border;
  final Color? backgroundColor;

  /// Use [Clip.antiAlias] when an inner widget paints to the card edge
  /// (e.g. a colored totals strip, a gradient banner) and would otherwise
  /// poke past the rounded corners.
  final Clip clipBehavior;

  static const List<BoxShadow> _shadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 4)),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.large);
    final tappable = onTap != null;

    // When tappable, the surrounding `Material` paints the surface so
    // ink splashes are visible; the inner Container then only owns border
    // and shadow. When static, the Container paints everything.
    final inner = Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: tappable ? null : (backgroundColor ?? AppColors.surfaceContainerLowest),
        borderRadius: radius,
        border: border,
        boxShadow: _shadow,
      ),
      child: child,
    );

    if (!tappable) return inner;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: radius,
      child: InkWell(onTap: onTap, borderRadius: radius, child: inner),
    );
  }
}
