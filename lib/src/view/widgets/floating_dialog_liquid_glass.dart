// Internal: not exported from the package.
// ignore_for_file: public_member_api_docs

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// macOS "Liquid Glass": blurred, saturated backdrop, a translucent tint
/// with a soft sheen, a bright rim and a deep soft shadow.
class FloatingDialogLiquidGlass extends StatelessWidget {
  const FloatingDialogLiquidGlass({
    super.key,
    required this.borderRadius,
    required this.child,
    this.tint,
    this.blur = 28,
    this.shadow = true,
  });

  final BorderRadius borderRadius;
  final Widget child;

  /// Glass color; defaults to the theme's surface.
  final Color? tint;
  final double blur;
  final bool shadow;

  static ui.ColorFilter _saturate(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return ui.ColorFilter.matrix([
      r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ?? Theme.of(context).colorScheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow:
            shadow
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.45 : 0.18),
                    blurRadius: 42,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.3 : 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.compose(
            outer: _saturate(1.8),
            inner: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          ),
          child: CustomPaint(
            foregroundPainter: _RimPainter(borderRadius, dark),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    base.withValues(alpha: dark ? 0.52 : 0.64),
                    base.withValues(alpha: dark ? 0.38 : 0.46),
                  ],
                ),
              ),
              child: DecoratedBox(
                // Specular sheen across the top.
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.35],
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.10 : 0.28),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bright, uneven rim of the glass.
class _RimPainter extends CustomPainter {
  _RimPainter(this.radius, this.dark);

  final BorderRadius radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect);
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.35, 0.65, 1],
          colors: [
            Colors.white.withValues(alpha: dark ? 0.45 : 0.85),
            Colors.white.withValues(alpha: dark ? 0.08 : 0.15),
            Colors.white.withValues(alpha: dark ? 0.04 : 0.08),
            Colors.white.withValues(alpha: dark ? 0.25 : 0.5),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect.deflate(0.25),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.black.withValues(alpha: dark ? 0.5 : 0.1),
    );
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.dark != dark;
}
