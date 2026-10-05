import 'package:flutter/widgets.dart';

import '../config/floating_dialog_config.dart';
import 'floating_dialog_window_frame.dart';

/// Builds a holder item's icon in the given [color] and [size], e.g. an SVG:
///
/// ```dart
/// iconBuilder: (context, color, size) => SvgPicture.asset(
///   'assets/treasury.svg',
///   width: size,
///   height: size,
///   colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
/// ),
/// ```
typedef FloatingDialogIconBuilder =
    Widget Function(BuildContext context, Color color, double size);

/// Describes a dialog that can float: what to build and how it is shown in
/// the holder. `showFloatingDialog` creates one for you; build one yourself
/// to reuse it or to register it with `FloatingDialogHolder.registerActions`.
@immutable
class FloatingDialogAction {
  /// Creates a floating dialog description.
  const FloatingDialogAction({
    required this.id,
    required this.title,
    required this.builder,
    this.icon,
    this.iconBuilder,
    this.canPause,
    this.isAvailable,
    this.isRestorable = false,
    this.showFrame = true,
    this.size,
    this.headerActions = const [],
    this.windowButtons,
    this.frameBuilder,
    this.originKey,
  });

  /// Stable identity: one window per id, and the key used when saving.
  /// Opening an id that is already held restores that window.
  final String id;

  /// Window title, holder tooltip and screen reader label.
  final String title;

  /// Builds the dialog content. Any existing dialog widget works unchanged:
  /// `Navigator.pop(context, result)` closes the window with that result,
  /// and dialogs opened from inside stay above it.
  final WidgetBuilder builder;

  /// Icon of the holder item. Ignored when [iconBuilder] is set.
  final IconData? icon;

  /// Custom holder item icon (SVG, image, ...). Wins over [icon].
  final FloatingDialogIconBuilder? iconBuilder;

  /// Whether the dialog may be minimized right now. While it returns false
  /// the window stays open and the user is told why.
  final bool Function()? canPause;

  /// Whether the current user may (still) open this dialog. Re-checked
  /// before every restore and whenever the holder's `availabilityChanges`
  /// notifies; a window that loses access is closed.
  final bool Function()? isAvailable;

  /// Whether the holder item is saved and shown (greyed) after an app
  /// restart. Needs persistent storage and the action registered on start
  /// (see `FloatingDialogHolder.registerActions`). Off by default.
  final bool isRestorable;

  /// Wraps [builder] in the built-in window frame (title bar with the
  /// minimize / pin / maximize / close buttons). Set to false when the
  /// content draws its own header with `FloatingDialogWindowActions`.
  final bool showFrame;

  /// Normal window size for this dialog; defaults to the config's size for
  /// the current device.
  final FloatingDialogSizeFactor? size;

  /// Extra header buttons, shown before the built-in ones.
  final List<FloatingDialogHeaderAction> headerActions;

  /// Which built-in header buttons to show; defaults to the config's
  /// `windowButtons` (all four).
  final Set<FloatingDialogWindowButton>? windowButtons;

  /// Custom chrome for this dialog; defaults to the config's
  /// `windowFrameBuilder`, then the built-in frame.
  final FloatingDialogWindowFrameBuilder? frameBuilder;

  /// The widget the dialog was opened from (an image, a button...). Give
  /// that widget this key: the window grows out of it on open and shrinks
  /// back into it on close, like a [Hero].
  final GlobalKey? originKey;

  /// [canPause], evaluated now.
  bool get canPauseNow => canPause?.call() ?? true;

  /// [isAvailable], evaluated now.
  bool get isAvailableNow => isAvailable?.call() ?? true;
}
