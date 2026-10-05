import 'package:flutter/material.dart';

/// Colors of the floating windows, holder bar and pinned dock.
///
/// Every color is optional; unset colors come from the app's [ColorScheme],
/// so light and dark themes work out of the box. Set them in either place:
///
/// * `FloatingDialogConfig(colors: FloatingDialogColors(...))`: one palette
///   for every theme.
/// * `ThemeData(extensions: [FloatingDialogColors(...)])`: a palette per
///   theme (light / dark), animated on theme changes. Values set here win
///   over the config.
@immutable
class FloatingDialogColors extends ThemeExtension<FloatingDialogColors> {
  /// Creates a palette; unset colors fall back to the theme.
  const FloatingDialogColors({
    this.headerBackground,
    this.headerForeground,
    this.windowBackground,
    this.barrier,
    this.holderBackground,
    this.holderBorder,
    this.holderShadow,
    this.item,
    this.dimmedItem,
    this.badgeBackground,
    this.badgeForeground,
    this.dockIndicator,
    this.dockClose,
  });

  /// Header bar of the built-in frame. Defaults to `primary`.
  final Color? headerBackground;

  /// Title and window buttons of the built-in frame. Defaults to `onPrimary`.
  final Color? headerForeground;

  /// Body of the built-in frame. Defaults to `surface`.
  final Color? windowBackground;

  /// Barrier behind the active window. Defaults to translucent black.
  final Color? barrier;

  /// Holder bar and dock background. Defaults to translucent `surface`.
  final Color? holderBackground;

  /// Holder bar and dock border. Defaults to translucent `outline`.
  final Color? holderBorder;

  /// Holder bar and dock shadow. Defaults to translucent `shadow`.
  final Color? holderShadow;

  /// Icon and outline of holder items. Defaults to `primary`.
  final Color? item;

  /// Icon and outline of dormant (evicted) items. Defaults to translucent
  /// `onSurface`.
  final Color? dimmedItem;

  /// Count badge on the collapsed holder. Defaults to `primary`.
  final Color? badgeBackground;

  /// Count badge text. Defaults to `onPrimary`.
  final Color? badgeForeground;

  /// Collapsed dock indicator. Defaults to translucent `primary`.
  final Color? dockIndicator;

  /// Close button next to dock items. Defaults to `error`.
  final Color? dockClose;

  /// Every color resolved for [context]: theme extension first, then
  /// [fallback] (usually the config's palette), then the color scheme.
  static FloatingDialogColors resolve(
    BuildContext context, [
    FloatingDialogColors? fallback,
  ]) {
    final scheme = Theme.of(context).colorScheme;
    final defaults = FloatingDialogColors(
      headerBackground: scheme.primary,
      headerForeground: scheme.onPrimary,
      windowBackground: scheme.surface,
      barrier: Colors.black54,
      holderBackground: scheme.surface.withValues(alpha: 0.72),
      holderBorder: scheme.outline.withValues(alpha: 0.35),
      holderShadow: scheme.shadow.withValues(alpha: 0.12),
      item: scheme.primary,
      dimmedItem: scheme.onSurface.withValues(alpha: 0.38),
      badgeBackground: scheme.primary,
      badgeForeground: scheme.onPrimary,
      dockIndicator: scheme.primary.withValues(alpha: 0.72),
      dockClose: scheme.error,
    );
    final themed = Theme.of(context).extension<FloatingDialogColors>();
    return defaults._overriddenBy(fallback)._overriddenBy(themed);
  }

  FloatingDialogColors _overriddenBy(FloatingDialogColors? other) =>
      other == null
          ? this
          : copyWith(
            headerBackground: other.headerBackground,
            headerForeground: other.headerForeground,
            windowBackground: other.windowBackground,
            barrier: other.barrier,
            holderBackground: other.holderBackground,
            holderBorder: other.holderBorder,
            holderShadow: other.holderShadow,
            item: other.item,
            dimmedItem: other.dimmedItem,
            badgeBackground: other.badgeBackground,
            badgeForeground: other.badgeForeground,
            dockIndicator: other.dockIndicator,
            dockClose: other.dockClose,
          );

  @override
  FloatingDialogColors copyWith({
    Color? headerBackground,
    Color? headerForeground,
    Color? windowBackground,
    Color? barrier,
    Color? holderBackground,
    Color? holderBorder,
    Color? holderShadow,
    Color? item,
    Color? dimmedItem,
    Color? badgeBackground,
    Color? badgeForeground,
    Color? dockIndicator,
    Color? dockClose,
  }) => FloatingDialogColors(
    headerBackground: headerBackground ?? this.headerBackground,
    headerForeground: headerForeground ?? this.headerForeground,
    windowBackground: windowBackground ?? this.windowBackground,
    barrier: barrier ?? this.barrier,
    holderBackground: holderBackground ?? this.holderBackground,
    holderBorder: holderBorder ?? this.holderBorder,
    holderShadow: holderShadow ?? this.holderShadow,
    item: item ?? this.item,
    dimmedItem: dimmedItem ?? this.dimmedItem,
    badgeBackground: badgeBackground ?? this.badgeBackground,
    badgeForeground: badgeForeground ?? this.badgeForeground,
    dockIndicator: dockIndicator ?? this.dockIndicator,
    dockClose: dockClose ?? this.dockClose,
  );

  @override
  FloatingDialogColors lerp(FloatingDialogColors? other, double t) {
    if (other == null) return this;
    Color? c(Color? a, Color? b) => Color.lerp(a, b, t);
    return FloatingDialogColors(
      headerBackground: c(headerBackground, other.headerBackground),
      headerForeground: c(headerForeground, other.headerForeground),
      windowBackground: c(windowBackground, other.windowBackground),
      barrier: c(barrier, other.barrier),
      holderBackground: c(holderBackground, other.holderBackground),
      holderBorder: c(holderBorder, other.holderBorder),
      holderShadow: c(holderShadow, other.holderShadow),
      item: c(item, other.item),
      dimmedItem: c(dimmedItem, other.dimmedItem),
      badgeBackground: c(badgeBackground, other.badgeBackground),
      badgeForeground: c(badgeForeground, other.badgeForeground),
      dockIndicator: c(dockIndicator, other.dockIndicator),
      dockClose: c(dockClose, other.dockClose),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FloatingDialogColors &&
      other.headerBackground == headerBackground &&
      other.headerForeground == headerForeground &&
      other.windowBackground == windowBackground &&
      other.barrier == barrier &&
      other.holderBackground == holderBackground &&
      other.holderBorder == holderBorder &&
      other.holderShadow == holderShadow &&
      other.item == item &&
      other.dimmedItem == dimmedItem &&
      other.badgeBackground == badgeBackground &&
      other.badgeForeground == badgeForeground &&
      other.dockIndicator == dockIndicator &&
      other.dockClose == dockClose;

  @override
  int get hashCode => Object.hash(
    headerBackground,
    headerForeground,
    windowBackground,
    barrier,
    holderBackground,
    holderBorder,
    holderShadow,
    item,
    dimmedItem,
    badgeBackground,
    badgeForeground,
    dockIndicator,
    dockClose,
  );
}
