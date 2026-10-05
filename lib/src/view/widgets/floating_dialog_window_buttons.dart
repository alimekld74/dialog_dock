// Internal: not exported from the package.
// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

import '../../host/floating_dialog_host_context.dart';

/// One header button.
class FloatingDialogButtonSpec {
  const FloatingDialogButtonSpec({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.light,
    this.destructive = false,
    this.custom,
    this.decoration,
  });

  final String tooltip;

  /// The symbol; a [Widget] builder so custom (SVG) icons work too.
  final Widget Function(Color color, double size) icon;
  final VoidCallback onPressed;

  /// Traffic light color.
  final Color? light;

  /// Turns red on hover in the tonal style.
  final bool destructive;

  /// Replaces the whole look (symbol and decoration).
  final Widget? custom;

  /// Replaces the style's background.
  final Decoration? decoration;
}

/// macOS traffic light colors.
abstract final class FloatingDialogLights {
  static const close = Color(0xFFFF5F57);
  static const minimize = Color(0xFFFEBC2E);
  static const maximize = Color(0xFF28C840);
  static const pinned = Color(0xFF4E9BFF);
  static const unpinned = Color(0xFFB4B4BB);
}

/// Hover / press / keyboard focus handling shared by both styles.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.spec, required this.builder, this.onHover});

  final FloatingDialogButtonSpec spec;
  final Widget Function(bool hovered, bool pressed, bool focused) builder;

  /// Reports pointer hover changes.
  final ValueChanged<bool>? onHover;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  void _hover(bool value) {
    setState(() => _hovered = value);
    widget.onHover?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.spec.tooltip,
      child: Semantics(
        button: true,
        label: widget.spec.tooltip,
        excludeSemantics: true,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: _hover,
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.spec.onPressed();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.spec.onPressed,
            child: widget.builder(_hovered, _pressed, _focused),
          ),
        ),
      ),
    );
  }
}

/// macOS-style traffic lights. Symbols show while the group is hovered, or
/// always on touch devices.
class FloatingDialogTrafficLights extends StatefulWidget {
  const FloatingDialogTrafficLights({
    super.key,
    required this.buttons,
    this.diameter = 16,
    this.hoverScale = 1.35,
  });

  final List<FloatingDialogButtonSpec> buttons;
  final double diameter;

  /// Scale of the hovered light; neighbours grow by a third of that.
  final double hoverScale;

  @override
  State<FloatingDialogTrafficLights> createState() =>
      _FloatingDialogTrafficLightsState();
}

class _FloatingDialogTrafficLightsState
    extends State<FloatingDialogTrafficLights> {
  bool _groupHovered = false;
  int? _hoveredIndex;

  /// Dock-style magnification: the hovered light grows most, its
  /// neighbours a little.
  double _scaleOf(int index) {
    final hovered = _hoveredIndex;
    if (hovered == null) return 1;
    return switch ((index - hovered).abs()) {
      0 => widget.hoverScale,
      1 => 1 + (widget.hoverScale - 1) / 3,
      _ => 1,
    };
  }

  @override
  Widget build(BuildContext context) {
    final touch = context.isFloatingMobile || context.isFloatingTablet;
    final showSymbols = touch || _groupHovered;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final diameter = widget.diameter;
    final target = diameter + 14;
    return MouseRegion(
      onEnter: (_) => setState(() => _groupHovered = true),
      onExit:
          (_) => setState(() {
            _groupHovered = false;
            _hoveredIndex = null;
          }),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, end: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, spec) in widget.buttons.indexed)
              _Pressable(
                spec: spec,
                onHover:
                    (hovered) => setState(() {
                      if (hovered) {
                        _hoveredIndex = index;
                      } else if (_hoveredIndex == index) {
                        _hoveredIndex = null;
                      }
                    }),
                builder: (hovered, pressed, focused) {
                  final base = spec.light ?? FloatingDialogLights.unpinned;
                  final fill =
                      pressed ? Color.lerp(base, Colors.black, 0.18)! : base;
                  final custom = spec.custom;
                  final Widget face;
                  if (custom != null) {
                    face = custom;
                  } else {
                    final symbol = AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: showSymbols ? 1 : 0,
                      child: Center(
                        child: spec.icon(
                          Colors.black.withValues(alpha: 0.6),
                          diameter * 0.7,
                        ),
                      ),
                    );
                    face = AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: diameter,
                      height: diameter,
                      decoration:
                          spec.decoration ??
                          BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.lerp(fill, Colors.white, 0.18)!,
                                fill,
                              ],
                            ),
                            border: Border.all(
                              color:
                                  Color.lerp(
                                    fill,
                                    dark ? Colors.white : Colors.black,
                                    dark ? 0.12 : 0.16,
                                  )!,
                              width: 0.6,
                            ),
                            boxShadow: [
                              if (focused)
                                BoxShadow(
                                  color: base.withValues(alpha: 0.55),
                                  spreadRadius: 2.5,
                                ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 1.5,
                                offset: const Offset(0, 0.5),
                              ),
                            ],
                          ),
                      child: symbol,
                    );
                  }
                  return SizedBox.square(
                    dimension: target,
                    child: Center(
                      child: AnimatedScale(
                        scale: _scaleOf(index),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        child: face,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// A soft rounded-square button tinted with [color].
class FloatingDialogTonalButton extends StatelessWidget {
  const FloatingDialogTonalButton({
    super.key,
    required this.spec,
    required this.color,
    this.size = 30,
  });

  final FloatingDialogButtonSpec spec;
  final Color color;
  final double size;

  static const _danger = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _Pressable(
        spec: spec,
        builder: (hovered, pressed, focused) {
          final custom = spec.custom;
          if (custom != null) {
            return AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale:
                  pressed
                      ? 0.9
                      : hovered
                      ? 1.08
                      : 1,
              child: custom,
            );
          }
          final danger = spec.destructive && (hovered || pressed);
          final background =
              danger
                  ? (pressed
                      ? Color.lerp(_danger, Colors.black, 0.15)!
                      : _danger)
                  : color.withValues(
                    alpha:
                        pressed
                            ? 0.2
                            : hovered
                            ? 0.13
                            : 0.06,
                  );
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: size,
            height: size,
            decoration:
                spec.decoration ??
                BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color:
                        focused
                            ? color.withValues(alpha: 0.6)
                            : color.withValues(alpha: danger ? 0 : 0.08),
                    width: focused ? 1.5 : 0.8,
                  ),
                ),
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 120),
                scale: pressed ? 0.88 : 1,
                child: spec.icon(danger ? Colors.white : color, size * 0.57),
              ),
            ),
          );
        },
      ),
    );
  }
}
