import 'package:flutter/widgets.dart';

import '../config/floating_dialog_colors.dart';
import 'floating_dialog_action.dart';

/// The built-in buttons of a floating window header.
enum FloatingDialogWindowButton {
  /// Sends the window to the holder.
  minimize,

  /// Pins the window to the screen edge.
  pin,

  /// Maximizes or restores the window size.
  maximize,

  /// Closes the window.
  close,
}

/// An extra button in a window header, shown before the built-in buttons.
///
/// ```dart
/// FloatingDialogHeaderAction(
///   tooltip: 'Print',
///   icon: Icons.print_outlined,
///   onPressed: (context) => printInvoice(),
/// )
/// ```
@immutable
class FloatingDialogHeaderAction {
  /// Creates a header button; give it an [icon] or an [iconBuilder].
  const FloatingDialogHeaderAction({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.iconBuilder,
    this.decoration,
  }) : assert(icon != null || iconBuilder != null, 'Give an icon');

  /// Tooltip and screen reader label.
  final String tooltip;

  /// Icon; ignored when [iconBuilder] is set.
  final IconData? icon;

  /// Custom icon (SVG, image, ...); wins over [icon].
  final FloatingDialogIconBuilder? iconBuilder;

  /// Background of this button, replacing the window button style's look
  /// (e.g. `BoxDecoration(color: Colors.teal, shape: BoxShape.circle)`).
  final Decoration? decoration;

  /// Called on tap with a context inside the window, so
  /// `Navigator.pop(context, result)` closes the window.
  final void Function(BuildContext context) onPressed;
}

/// Everything a custom window frame needs; see
/// `FloatingDialogConfig.windowFrameBuilder`.
@immutable
class FloatingDialogFrameDetails {
  /// Created by the holder.
  const FloatingDialogFrameDetails({
    required this.title,
    required this.buttons,
    required this.body,
    required this.colors,
    required this.isLarge,
    required this.isPinned,
    required this.isFloating,
  });

  /// The dialog title.
  final String title;

  /// The header buttons: extra header actions, then the built-in window
  /// buttons (or a close button when not floating). Place it in your header.
  final Widget buttons;

  /// The dialog content. Give it the remaining space.
  final Widget body;

  /// Resolved colors (theme, config, theme extension).
  final FloatingDialogColors colors;

  /// Whether the window is maximized.
  final bool isLarge;

  /// Whether the window is pinned.
  final bool isPinned;

  /// False when the same dialog is shown with a regular `showDialog`.
  final bool isFloating;
}

/// Builds a window's chrome around `details.body`.
///
/// ```dart
/// windowFrameBuilder: (context, d) => Card(
///   clipBehavior: Clip.antiAlias,
///   child: Column(children: [
///     ListTile(title: Text(d.title), trailing: d.buttons),
///     Expanded(child: d.body),
///   ]),
/// ),
/// ```
typedef FloatingDialogWindowFrameBuilder =
    Widget Function(BuildContext context, FloatingDialogFrameDetails details);
