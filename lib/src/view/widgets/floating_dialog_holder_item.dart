// Internal: not exported from the package.
// ignore_for_file: public_member_api_docs

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../host/floating_dialog_host_context.dart';
import '../../models/floating_dialog_action.dart';
import 'floating_dialog_liquid_glass.dart';

/// Translucent, blurred rounded surface shared by the holder bar and dock.
class FloatingDialogGlassSurface extends StatelessWidget {
  const FloatingDialogGlassSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final config = context.floatingConfig;
    final colors = context.floatingColors;
    final radius = BorderRadius.circular(config.holderRadius);
    if (config.liquidGlass) {
      return FloatingDialogLiquidGlass(
        borderRadius: radius,
        blur: 22,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: EdgeInsets.all(config.holderPadding),
            child: child,
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.holderShadow!,
            blurRadius: config.holderShadowBlur,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: config.holderBlurSigma,
            sigmaY: config.holderBlurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.holderBackground,
              borderRadius: radius,
              border: Border.all(color: colors.holderBorder!),
            ),
            // The holder sits outside any Scaffold, so ink needs a Material.
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: EdgeInsets.all(config.holderPadding),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An action's icon: its `iconBuilder` (SVG, image, ...) or its `icon`.
class FloatingDialogActionIcon extends StatelessWidget {
  FloatingDialogActionIcon({
    super.key,
    required FloatingDialogAction? action,
    required this.color,
    required this.size,
  }) : icon = action?.icon,
       iconBuilder = action?.iconBuilder;

  const FloatingDialogActionIcon.forHeader({
    super.key,
    required this.icon,
    required this.iconBuilder,
    required this.color,
    required this.size,
  });

  final IconData? icon;
  final FloatingDialogIconBuilder? iconBuilder;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final builder = iconBuilder;
    if (builder != null) {
      return SizedBox.square(
        dimension: size,
        child: builder(context, color, size),
      );
    }
    return Icon(icon ?? Icons.web_asset_outlined, color: color, size: size);
  }
}

/// Circular holder item.
class FloatingDialogCircle extends StatelessWidget {
  const FloatingDialogCircle({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
    this.onLongPress,
    this.longPressHint,
    this.badgeCount,
    this.dimmed = false,
  });

  /// Builds the icon in the given color and size.
  final Widget Function(Color color, double size) icon;

  /// Screen reader label and first tooltip line.
  final String label;

  /// Extra tooltip lines (also read by screen readers).
  final String? hint;
  final VoidCallback onTap;

  /// Also bound to secondary (right) click for desktop.
  final VoidCallback? onLongPress;
  final String? longPressHint;
  final int? badgeCount;

  /// Greyed look for dormant items.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final config = context.floatingConfig;
    final colors = context.floatingColors;
    final diameter = config.itemDiameter(isTouch: !context.isFloatingDesktop);
    final tint = dimmed ? colors.dimmedItem! : colors.item!;
    final circle = Material(
      color: tint.withValues(alpha: tint.a * config.itemFillOpacity),
      shape: CircleBorder(
        side: BorderSide(color: tint.withValues(alpha: tint.a * 0.35)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: SizedBox.square(
          dimension: diameter,
          child: Center(child: icon(tint, config.holderIconSize)),
        ),
      ),
    );

    final count = badgeCount;
    final tooltip = [label, if (hint != null) hint!].join('\n');
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      value: count == null ? null : '$count',
      onLongPressHint: longPressHint,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child:
            count == null
                ? circle
                : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    circle,
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: IgnorePointer(
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: config.holderBadgeSize,
                            minHeight: config.holderBadgeSize,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.badgeBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color: colors.badgeForeground,
                              height: 1,
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
