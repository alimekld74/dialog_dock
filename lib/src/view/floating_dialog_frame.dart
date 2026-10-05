import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/floating_dialog_colors.dart';
import '../config/floating_dialog_config.dart';
import '../models/floating_dialog_window_frame.dart';
import 'floating_dialog_scope.dart';
import 'widgets/floating_dialog_liquid_glass.dart';
import 'widgets/floating_dialog_window_actions.dart';

/// Dialog chrome: a title bar and a body, adapting to where it is shown.
///
/// * With `showDialog` it is a regular dialog with a close button.
/// * Inside a floating window it fills the window and shows the window
///   buttons.
/// * Inside a window that already has the holder's frame (the default for
///   `showFloatingDialog`), it shows only its body, so the same widget never
///   gets two title bars.
///
/// The look follows `FloatingDialogConfig` (colors, `headerTextStyle`,
/// `frameShape`) or is replaced entirely by a `windowFrameBuilder` /
/// [frameBuilder].
class FloatingDialogFrame extends StatelessWidget {
  /// Creates a frame.
  const FloatingDialogFrame({
    super.key,
    required this.title,
    required this.child,
    this.width,
    this.height,
    this.headerActions = const [],
    this.frameBuilder,
  });

  /// Title bar text.
  final String title;

  /// Dialog body.
  final Widget child;

  /// Width as a regular dialog; ignored in a floating window.
  final double? width;

  /// Height as a regular dialog; ignored in a floating window.
  final double? height;

  /// Extra header buttons, shown before the window buttons.
  final List<FloatingDialogHeaderAction> headerActions;

  /// Custom chrome; wins over the dialog's and the config's frame builder.
  final FloatingDialogWindowFrameBuilder? frameBuilder;

  @override
  Widget build(BuildContext context) {
    final scope = FloatingDialogScope.maybeOf(context);
    final config = scope?.holder.config ?? const FloatingDialogConfig();
    final colors = FloatingDialogColors.resolve(context, config.colors);
    final bodyPadding = EdgeInsets.symmetric(
      horizontal: config.frameBodyPadding,
    );
    if (scope != null && scope.hasFrame) {
      return Padding(padding: bodyPadding, child: child);
    }

    final floating = scope != null;
    final entry = scope?.holder.state.entryOf(scope.entryId);
    final custom =
        frameBuilder ??
        scope?.holder.actionOf(scope.entryId)?.frameBuilder ??
        config.windowFrameBuilder;
    // A custom frame draws its own header: buttons follow its icon theme.
    final foreground = custom == null ? colors.headerForeground! : null;
    final buttons =
        floating
            ? FloatingDialogWindowActions(
              color: foreground,
              extraActions: headerActions,
            )
            : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingDialogWindowActions(
                  color: foreground,
                  extraActions: headerActions,
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.close, color: foreground),
                ),
              ],
            );

    if (custom != null) {
      final framed = custom(
        context,
        FloatingDialogFrameDetails(
          title: title,
          buttons: buttons,
          body: child,
          colors: colors,
          isLarge: entry?.isLarge ?? false,
          isPinned: entry?.isPinned ?? false,
          isFloating: floating,
        ),
      );
      if (floating) return framed;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(width: width, height: height, child: framed),
      );
    }

    final glass = config.liquidGlass;
    // On glass the header blends into the window, so its text follows the
    // surface unless a header color was set explicitly.
    final explicitForeground =
        Theme.of(context).extension<FloatingDialogColors>()?.headerForeground ??
        config.colors?.headerForeground;
    final headerForeground =
        glass
            ? explicitForeground ?? Theme.of(context).colorScheme.onSurface
            : colors.headerForeground!;
    final leading =
        floating &&
        config.resolvedWindowButtonsPlacement ==
            FloatingDialogWindowButtonsPlacement.leading;
    final titleText = Semantics(
      header: true,
      child: Text(
        title,
        maxLines: leading ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        textAlign: leading ? TextAlign.center : TextAlign.start,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: headerForeground, fontWeight: FontWeight.w600)
            .merge(config.headerTextStyle),
      ),
    );
    final Widget headerRow;
    if (leading) {
      // macOS: window buttons first, title centered, extras at the end.
      headerRow = NavigationToolbar(
        leading: FloatingDialogWindowActions(
          color: headerForeground,
          showExtraActions: false,
        ),
        middle: titleText,
        trailing: FloatingDialogWindowActions(
          color: headerForeground,
          extraActions: headerActions,
          showWindowButtons: false,
        ),
        middleSpacing: 8,
      );
    } else {
      headerRow = Row(
        children: [
          Expanded(child: titleText),
          if (floating)
            FloatingDialogWindowActions(
              color: headerForeground,
              extraActions: headerActions,
            )
          else
            buttons,
        ],
      );
    }
    final headerHeight = config.headerHeight;
    final header = Container(
      color: glass ? null : colors.headerBackground,
      height: headerHeight ?? (leading ? 52 : null),
      padding: config.headerPadding,
      alignment: Alignment.center,
      child: headerRow,
    );

    final expandBody = height != null || floating;
    final content = Column(
      mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (expandBody)
          Expanded(child: Padding(padding: bodyPadding, child: child))
        else
          Flexible(child: Padding(padding: bodyPadding, child: child)),
      ],
    );

    if (glass && config.frameShape == null) {
      final radius = BorderRadius.circular(math.max(config.frameRadius, 20));
      final framed = Material(
        type: MaterialType.transparency,
        child: FloatingDialogLiquidGlass(borderRadius: radius, child: content),
      );
      if (floating) return framed;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(width: width, height: height, child: framed),
      );
    }

    final shape =
        config.frameShape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(config.frameRadius),
        );
    if (floating) {
      return Material(
        shape: shape,
        clipBehavior: Clip.antiAlias,
        color: colors.windowBackground,
        elevation: config.windowElevation,
        child: content,
      );
    }
    return Dialog(
      shape: shape,
      clipBehavior: Clip.antiAlias,
      backgroundColor: colors.windowBackground,
      child: SizedBox(width: width, height: height, child: content),
    );
  }
}
