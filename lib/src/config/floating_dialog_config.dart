import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/floating_dialog_window_frame.dart';
import 'floating_dialog_colors.dart';

/// Width and height of a floating window as fractions of the available area.
@immutable
class FloatingDialogSizeFactor {
  /// Creates a size factor; both values are fractions in `(0, 1]`.
  const FloatingDialogSizeFactor({required this.width, required this.height});

  /// Fraction of the available width.
  final double width;

  /// Fraction of the available height.
  final double height;

  /// The window size for an [available] area.
  Size resolve(Size available) =>
      Size(available.width * width, available.height * height);
}

/// How a window animates into its holder item when minimized.
enum FloatingDialogMinimizeEffect {
  /// Like the macOS Dock "Genie" effect: the window funnels into its item.
  genie,

  /// Like the macOS Dock "Scale" effect: the window shrinks into its item.
  scale,

  /// A quick fade.
  fade,
}

/// The look of the window's header buttons.
enum FloatingDialogWindowButtonStyle {
  /// macOS-style colored circles: close red, minimize yellow, maximize
  /// green, pin blue (grey while unpinned). Symbols appear on hover, and
  /// always on touch devices.
  trafficLights,

  /// Soft rounded squares tinted with the header color; close turns red on
  /// hover.
  tonal,

  /// Plain icon buttons.
  plain,
}

/// Which side of the header the built-in window buttons sit on.
enum FloatingDialogWindowButtonsPlacement {
  /// Start of the header, in the macOS order close, minimize, maximize,
  /// pin; the title is centered.
  leading,

  /// End of the header, in the order minimize, pin, maximize, close; the
  /// title starts at the leading edge.
  trailing,
}

/// Replacements for the built-in window buttons' symbols. A widget given
/// here is shown as is: the [FloatingDialogConfig.windowButtonStyle]
/// decoration is not drawn behind it, so bring your own (an SVG, an image,
/// a decorated container). Taps, tooltips and hover magnification still
/// work. Null keeps the built-in look.
@immutable
class FloatingDialogWindowButtonIcons {
  /// Creates replacements; leave a button null to keep its default.
  const FloatingDialogWindowButtonIcons({
    this.minimize,
    this.pin,
    this.unpin,
    this.maximize,
    this.restoreSize,
    this.close,
  });

  /// Minimize button.
  final Widget? minimize;

  /// Pin button while the window is not pinned.
  final Widget? pin;

  /// Pin button while the window is pinned.
  final Widget? unpin;

  /// Maximize button while the window has its normal size.
  final Widget? maximize;

  /// Maximize button while the window is maximized.
  final Widget? restoreSize;

  /// Close button.
  final Widget? close;
}

/// How a window that was never minimized animates when it closes (X, tap
/// outside, Back, Esc, `Navigator.pop`). A window opened with `originKey`
/// always shrinks back into that widget instead.
enum FloatingDialogCloseEffect {
  /// Drops towards the bottom center of the screen while shrinking and
  /// fading out.
  slideDown,

  /// Fades out in place with a slight shrink.
  fade,
}

/// Every tunable value of the floating dialog holder.
///
/// Pass an instance to `FloatingDialogHolder(config: ...)`; every field has
/// a default, so override only what you need:
///
/// ```dart
/// FloatingDialogHolder(
///   config: const FloatingDialogConfig(
///     holderBottomOffset: 72, // clear of the app's bottom bar
///     maxMountedWindows: 5,
///     colors: FloatingDialogColors(headerBackground: Colors.teal),
///   ),
///   child: child,
/// );
/// ```
@immutable
class FloatingDialogConfig {
  /// Creates a configuration; every value has a sensible default.
  const FloatingDialogConfig({
    this.colors,
    this.windowFrameBuilder,
    this.windowButtons = const {
      FloatingDialogWindowButton.minimize,
      FloatingDialogWindowButton.pin,
      FloatingDialogWindowButton.maximize,
      FloatingDialogWindowButton.close,
    },
    this.headerTextStyle,
    this.frameShape,
    this.defaultLifetime = const Duration(minutes: 15),
    this.lifetimePresets = const [
      Duration(minutes: 15),
      Duration(minutes: 30),
      Duration(hours: 1),
      Duration(hours: 2),
    ],
    this.customLifetimeMinMinutes = 1,
    this.customLifetimeMaxMinutes = 24 * 60,
    this.maxMountedWindows = 10,
    this.desktopNormalSize = const FloatingDialogSizeFactor(
      width: 0.64,
      height: 0.64,
    ),
    this.tabletNormalSize = const FloatingDialogSizeFactor(
      width: 0.8,
      height: 0.72,
    ),
    this.mobileNormalSize = const FloatingDialogSizeFactor(
      width: 0.96,
      height: 0.86,
    ),
    this.largeSize = const FloatingDialogSizeFactor(width: 0.96, height: 0.94),
    this.windowElevation = 24,
    this.windowActionIconSize = 20,
    this.windowActionSplashRadius = 18,
    this.windowButtonStyle = FloatingDialogWindowButtonStyle.trafficLights,
    this.windowButtonsPlacement,
    this.windowButtonIcons = const FloatingDialogWindowButtonIcons(),
    this.windowButtonDecoration,
    this.windowButtonSize,
    this.windowButtonHoverScale = 1.35,
    this.headerHeight,
    this.liquidGlass = false,
    this.dismissShortcut = const SingleActivator(LogicalKeyboardKey.escape),
    this.minimizeShortcut = const SingleActivator(
      LogicalKeyboardKey.keyM,
      control: true,
    ),
    this.holderBlurSigma = 12,
    this.holderShadowBlur = 16,
    this.itemFillOpacity = 0.12,
    this.holderRadius = 28,
    this.holderPadding = 6,
    this.holderItemSpacing = 6,
    this.holderBottomOffset = 16,
    this.holderEndOffset = 8,
    this.holderDraggable = true,
    this.holderMaxHeightFactor = 0.4,
    this.holderItemDiameter = 40,
    this.holderTouchItemDiameter = 48,
    this.holderIconSize = 20,
    this.holderBadgeSize = 16,
    this.dockEdgeOffset = 4,
    this.dockHoverStripWidth = 10,
    this.dockTouchStripWidth = 28,
    this.dockIndicatorWidth = 4,
    this.dockIndicatorHeight = 56,
    this.dockCloseSize = 18,
    this.dockCloseIconSize = 12,
    this.dockCloseTapTarget = 32,
    this.dockHoverCollapseDelay = const Duration(milliseconds: 600),
    this.dockTouchRevealDuration = const Duration(seconds: 4),
    this.dockAlwaysExpanded = false,
    this.settingsDialogWidth = 420,
    this.settingsMobileWidthFactor = 0.92,
    this.settingsSpacing = 16,
    this.mobileMaxWidth = 599,
    this.tabletMaxWidth = 1199,
    this.headerPadding = const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
    this.frameRadius = 12,
    this.frameBodyPadding = 12,
    this.minimizeEffect = FloatingDialogMinimizeEffect.genie,
    this.minimizeEffectDuration = const Duration(milliseconds: 380),
    this.openEffectDuration = const Duration(milliseconds: 220),
    this.closeEffect = FloatingDialogCloseEffect.slideDown,
    this.closeEffectDuration = const Duration(milliseconds: 260),
    this.windowAnimationDuration = const Duration(milliseconds: 180),
    this.resizeAnimationDuration = const Duration(milliseconds: 220),
    this.holderAnimationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeOutCubic,
  });

  /// Colors; unset ones come from the theme. A [FloatingDialogColors]
  /// theme extension overrides these per theme.
  final FloatingDialogColors? colors;

  /// Custom chrome for every window (header, shape, background). Receives
  /// the title, the header buttons and the body. A dialog's own
  /// `frameBuilder` wins.
  final FloatingDialogWindowFrameBuilder? windowFrameBuilder;

  /// Built-in header buttons shown by default. A dialog's own
  /// `windowButtons` wins.
  final Set<FloatingDialogWindowButton> windowButtons;

  /// Title style of the built-in frame; merged over `titleMedium`.
  final TextStyle? headerTextStyle;

  /// Shape of the built-in frame; defaults to rounded corners of
  /// [frameRadius].
  final ShapeBorder? frameShape;

  // Lifetime and memory.

  /// Lifetime of a minimized, unpinned window before it is evicted. Users
  /// can override it from the holder settings.
  final Duration defaultLifetime;

  /// Lifetime choices offered in the holder settings.
  final List<Duration> lifetimePresets;

  /// Smallest custom lifetime accepted in the holder settings, in minutes.
  final int customLifetimeMinMinutes;

  /// Largest custom lifetime accepted in the holder settings, in minutes.
  final int customLifetimeMaxMinutes;

  /// Most minimized, unpinned windows kept in memory. When exceeded, the
  /// least recently minimized one is evicted (turns dormant). `null` means
  /// no limit; pinned windows are never evicted.
  final int? maxMountedWindows;

  // Window sizes.

  /// Normal window size on desktop.
  final FloatingDialogSizeFactor desktopNormalSize;

  /// Normal window size on tablets.
  final FloatingDialogSizeFactor tabletNormalSize;

  /// Normal window size on phones (near full screen).
  final FloatingDialogSizeFactor mobileNormalSize;

  /// Maximized window size on every device.
  final FloatingDialogSizeFactor largeSize;

  /// The normal size factor for a device type.
  FloatingDialogSizeFactor normalSize({
    required bool isMobile,
    required bool isTablet,
  }) =>
      isMobile
          ? mobileNormalSize
          : isTablet
          ? tabletNormalSize
          : desktopNormalSize;

  // Window chrome and keyboard.

  /// Elevation of a floating window.
  final double windowElevation;

  /// Icon size of the window header actions.
  final double windowActionIconSize;

  /// Splash radius of the window header actions.
  final double windowActionSplashRadius;

  /// Look of the header buttons. Extra `headerActions` use the [tonal]
  /// look with [trafficLights], and match the style otherwise.
  ///
  /// [tonal]: FloatingDialogWindowButtonStyle.tonal
  /// [trafficLights]: FloatingDialogWindowButtonStyle.trafficLights
  final FloatingDialogWindowButtonStyle windowButtonStyle;

  /// Side of the built-in buttons. Null: leading (macOS) for
  /// [FloatingDialogWindowButtonStyle.trafficLights], trailing otherwise.
  /// Extra `headerActions` always sit at the trailing end.
  final FloatingDialogWindowButtonsPlacement? windowButtonsPlacement;

  /// The resolved [windowButtonsPlacement].
  FloatingDialogWindowButtonsPlacement get resolvedWindowButtonsPlacement =>
      windowButtonsPlacement ??
      (windowButtonStyle == FloatingDialogWindowButtonStyle.trafficLights
          ? FloatingDialogWindowButtonsPlacement.leading
          : FloatingDialogWindowButtonsPlacement.trailing);

  /// Custom symbols for the built-in buttons (shown without decoration).
  final FloatingDialogWindowButtonIcons windowButtonIcons;

  /// Background of every built-in button, replacing the
  /// [windowButtonStyle] look (e.g. a gradient circle). Ignored for buttons
  /// replaced through [windowButtonIcons] and by
  /// [FloatingDialogWindowButtonStyle.plain].
  final Decoration? windowButtonDecoration;

  /// Size of a built-in button. Null: 16 for traffic lights, 30 for tonal.
  final double? windowButtonSize;

  /// Scale of a hovered traffic light (its neighbours grow a little too),
  /// like the macOS Dock. 1 turns magnification off.
  final double windowButtonHoverScale;

  /// Fixed height of the window header. Null fits its content.
  final double? headerHeight;

  /// macOS "Liquid Glass": windows, the holder bar and the dock become
  /// frosted, translucent glass with a light rim, and the header blends
  /// into the window. Window corners are at least 20.
  final bool liquidGlass;

  /// Dismisses the active window like a tap outside it. Defaults to Esc.
  final ShortcutActivator? dismissShortcut;

  /// Minimizes the active window. Defaults to Ctrl+M.
  final ShortcutActivator? minimizeShortcut;

  // Holder bar.

  /// Backdrop blur of the holder bar and dock.
  final double holderBlurSigma;

  /// Shadow blur of the holder bar and dock.
  final double holderShadowBlur;

  /// Fill opacity of holder items, relative to their color.
  final double itemFillOpacity;

  /// Corner radius of the holder bar and dock.
  final double holderRadius;

  /// Inner padding of the holder bar and dock.
  final double holderPadding;

  /// Space between holder items.
  final double holderItemSpacing;

  /// Distance of the holder bar from the bottom edge. Raise it to clear a
  /// bottom navigation bar.
  final double holderBottomOffset;

  /// Distance of the holder bar from the end edge (start edge on phones).
  final double holderEndOffset;

  /// Users can drag the holder bar anywhere on the screen. The spot is kept
  /// in memory while the app runs (across windows and pages) and resets to
  /// the corner when the app restarts.
  final bool holderDraggable;

  /// Maximum holder bar height as a fraction of the screen height; extra
  /// items scroll.
  final double holderMaxHeightFactor;

  /// Item diameter with a mouse.
  final double holderItemDiameter;

  /// Item diameter on touch devices (phones and tablets).
  final double holderTouchItemDiameter;

  /// Icon size inside holder items.
  final double holderIconSize;

  /// Size of the count badge on the collapsed holder.
  final double holderBadgeSize;

  /// The item diameter for a pointer kind.
  double itemDiameter({required bool isTouch}) =>
      isTouch ? holderTouchItemDiameter : holderItemDiameter;

  // Pinned edge dock.

  /// Distance of the dock from the end edge.
  final double dockEdgeOffset;

  /// Hover area width of the collapsed dock with a mouse.
  final double dockHoverStripWidth;

  /// Tap area width of the collapsed dock on phones and tablets.
  final double dockTouchStripWidth;

  /// Width of the visible collapsed dock indicator.
  final double dockIndicatorWidth;

  /// Height of the visible collapsed dock indicator.
  final double dockIndicatorHeight;

  /// Diameter of the close button next to a dock item.
  final double dockCloseSize;

  /// Icon size of the close button next to a dock item.
  final double dockCloseIconSize;

  /// Tap target of the close button next to a dock item.
  final double dockCloseTapTarget;

  /// How long the dock stays revealed after the pointer leaves.
  final Duration dockHoverCollapseDelay;

  /// How long the dock stays revealed after a touch.
  final Duration dockTouchRevealDuration;

  /// Always show the pinned items instead of a thin indicator that expands
  /// on hover or tap. Off by default on every device.
  final bool dockAlwaysExpanded;

  // Settings dialog.

  /// Width of the holder settings dialog.
  final double settingsDialogWidth;

  /// Width of the holder settings dialog on phones, as a screen fraction.
  final double settingsMobileWidthFactor;

  /// Vertical spacing inside the holder settings dialog.
  final double settingsSpacing;

  // Breakpoints.

  /// Largest width treated as a phone by the default device detection.
  final double mobileMaxWidth;

  /// Largest width treated as a tablet by the default device detection.
  final double tabletMaxWidth;

  // Built-in frame.

  /// Header padding of `FloatingDialogFrame`.
  final EdgeInsetsGeometry headerPadding;

  /// Corner radius of `FloatingDialogFrame`.
  final double frameRadius;

  /// Horizontal body padding of `FloatingDialogFrame`.
  final double frameBodyPadding;

  // Animations.

  /// Animation into the holder item on minimize (played in reverse on
  /// restore). Skipped when the platform asks to reduce motion.
  final FloatingDialogMinimizeEffect minimizeEffect;

  /// Duration of [minimizeEffect].
  final Duration minimizeEffectDuration;

  /// Duration of the open animation (zoom in, or grow out of the
  /// dialog's `originKey` widget). Zero disables it.
  final Duration openEffectDuration;

  /// Animation of a window closing without having been minimized.
  final FloatingDialogCloseEffect closeEffect;

  /// Duration of the close animation ([closeEffect], or shrinking back into
  /// the `originKey` widget). Zero disables it.
  final Duration closeEffectDuration;

  /// Duration of the barrier fade.
  final Duration windowAnimationDuration;

  /// Duration of the maximize / restore size animation.
  final Duration resizeAnimationDuration;

  /// Duration of the holder bar and dock animations.
  final Duration holderAnimationDuration;

  /// Curve of every holder animation.
  final Curve animationCurve;
}
