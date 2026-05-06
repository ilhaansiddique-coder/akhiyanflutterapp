import 'package:flutter/material.dart';

/// Subtle pulsing gray rectangle used as a loading placeholder. Keeps the
/// page from reflowing when real data swaps in — sized boxes should match the
/// real card's dimensions.
///
/// Uses a plain opacity pulse (0.5 ↔ 1.0 over ~1.2s) rather than a shimmer
/// gradient — no extra dependency, and it's quiet enough to be ignorable.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Convenience placeholder shaped like a single line of text.
class SkeletonText extends StatelessWidget {
  const SkeletonText({
    super.key,
    this.width = 120,
    this.fontSize = 14,
  });

  final double width;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Slight vertical padding so the placeholder sits where the text baseline
    // would have been — keeps row heights stable when the real text arrives.
    return SkeletonBox(width: width, height: fontSize, radius: 4);
  }
}
