import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../controller/floating_dialog_holder_cubit.dart';
import '../../host/floating_dialog_host_context.dart';
import '../../models/floating_dialog_entry.dart';
import '../../config/floating_dialog_config.dart';
import '../../models/floating_dialog_window_frame.dart';
import '../floating_dialog_scope.dart';
import 'floating_dialog_holder_item.dart';
import 'floating_dialog_window_buttons.dart';

/// The header buttons of a floating window: the dialog's extra
/// `headerActions` (plus [extraActions]) and the built-in minimize / pin /
/// maximize / close buttons it allows, styled by
/// `FloatingDialogConfig.windowButtonStyle`. Use it in your own header when
/// the window has no frame (`showFrame: false`). Outside a floating window
/// it shows only the extra actions.
class FloatingDialogWindowActions extends StatelessWidget {
  /// Creates the buttons in [color] (defaults to the icon theme).
  const FloatingDialogWindowActions({
    super.key,
    this.color,
    this.extraActions = const [],
    this.showWindowButtons = true,
    this.showExtraActions = true,
  });

  /// Icon color.
  final Color? color;

  /// More buttons, shown before the dialog's own `headerActions`.
  final List<FloatingDialogHeaderAction> extraActions;

  /// Shows the built-in minimize / pin / maximize / close buttons.
  final bool showWindowButtons;

  /// Shows the extra actions ([extraActions] and the dialog's
  /// `headerActions`).
  final bool showExtraActions;

  @override
  Widget build(BuildContext context) {
    final scope = FloatingDialogScope.maybeOf(context);
    if (scope == null) {
      if (!showExtraActions) return const SizedBox.shrink();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final a in extraActions) _extra(context, a, 20, 18)],
      );
    }
    final holder = scope.holder;
    final config = holder.config;
    final strings = context.floatingStrings;
    final action = holder.actionOf(scope.entryId);
    final buttons = action?.windowButtons ?? config.windowButtons;
    final icons = config.windowButtonIcons;
    final style = config.windowButtonStyle;
    final leading =
        config.resolvedWindowButtonsPlacement ==
        FloatingDialogWindowButtonsPlacement.leading;
    final fg = color ?? IconTheme.of(context).color ?? Colors.black;

    return BlocSelector<
      FloatingDialogHolderCubit,
      FloatingDialogHolderState,
      FloatingDialogEntry?
    >(
      bloc: holder,
      selector: (state) => state.entryOf(scope.entryId),
      builder: (context, entry) {
        if (entry == null) return const SizedBox.shrink();
        Widget Function(Color, double) glyph(IconData icon) =>
            (color, size) => Icon(icon, color: color, size: size);
        final minimize =
            buttons.contains(FloatingDialogWindowButton.minimize)
                ? FloatingDialogButtonSpec(
                  tooltip: strings.minimize,
                  icon: glyph(
                    style == FloatingDialogWindowButtonStyle.plain
                        ? Icons.minimize
                        : Icons.remove_rounded,
                  ),
                  light: FloatingDialogLights.minimize,
                  custom: icons.minimize,
                  decoration: config.windowButtonDecoration,
                  onPressed: () => scope.minimize(context),
                )
                : null;
        final pin =
            buttons.contains(FloatingDialogWindowButton.pin)
                ? FloatingDialogButtonSpec(
                  tooltip: entry.isPinned ? strings.unpin : strings.pin,
                  icon: glyph(
                    entry.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  ),
                  light:
                      entry.isPinned
                          ? FloatingDialogLights.pinned
                          : FloatingDialogLights.unpinned,
                  custom: entry.isPinned ? icons.unpin : icons.pin,
                  decoration: config.windowButtonDecoration,
                  onPressed: () => holder.togglePin(scope.entryId),
                )
                : null;
        final maximize =
            buttons.contains(FloatingDialogWindowButton.maximize)
                ? FloatingDialogButtonSpec(
                  tooltip:
                      entry.isLarge ? strings.restoreSize : strings.maximize,
                  icon: glyph(
                    entry.isLarge
                        ? Icons.close_fullscreen_rounded
                        : Icons.open_in_full_rounded,
                  ),
                  light: FloatingDialogLights.maximize,
                  custom: entry.isLarge ? icons.restoreSize : icons.maximize,
                  decoration: config.windowButtonDecoration,
                  onPressed: () => holder.toggleSize(scope.entryId),
                )
                : null;
        final close =
            buttons.contains(FloatingDialogWindowButton.close)
                ? FloatingDialogButtonSpec(
                  tooltip: strings.close,
                  icon: glyph(
                    style == FloatingDialogWindowButtonStyle.plain
                        ? Icons.close
                        : Icons.close_rounded,
                  ),
                  light: FloatingDialogLights.close,
                  destructive: true,
                  custom: icons.close,
                  decoration: config.windowButtonDecoration,
                  onPressed: scope.close,
                )
                : null;
        // macOS order on the leading side; Windows-like on the trailing one.
        final specs =
            (leading
                    ? [close, minimize, maximize, pin]
                    : [minimize, pin, maximize, close])
                .nonNulls
                .toList();

        final extras = [
          if (showExtraActions) ...[...extraActions, ...?action?.headerActions],
        ];
        final builtIn = <Widget>[
          if (showWindowButtons && specs.isNotEmpty)
            ...switch (style) {
              FloatingDialogWindowButtonStyle.trafficLights => [
                FloatingDialogTrafficLights(
                  buttons: specs,
                  diameter: config.windowButtonSize ?? 16,
                  hoverScale: config.windowButtonHoverScale,
                ),
              ],
              FloatingDialogWindowButtonStyle.tonal => [
                for (final spec in specs)
                  FloatingDialogTonalButton(
                    spec: spec,
                    color: fg,
                    size: config.windowButtonSize ?? 30,
                  ),
              ],
              FloatingDialogWindowButtonStyle.plain => [
                for (final spec in specs)
                  IconButton(
                    tooltip: spec.tooltip,
                    splashRadius: config.windowActionSplashRadius,
                    onPressed: spec.onPressed,
                    icon:
                        spec.custom ??
                        spec.icon(fg, config.windowActionIconSize),
                  ),
              ],
            },
        ];
        final extraWidgets = <Widget>[
          for (final a in extras)
            style == FloatingDialogWindowButtonStyle.plain &&
                    a.decoration == null
                ? _extra(
                  context,
                  a,
                  config.windowActionIconSize,
                  config.windowActionSplashRadius,
                )
                : FloatingDialogTonalButton(
                  spec: _extraSpec(context, a),
                  color: fg,
                  size:
                      style == FloatingDialogWindowButtonStyle.tonal
                          ? config.windowButtonSize ?? 30
                          : 30,
                ),
        ];
        final gap =
            extraWidgets.isNotEmpty && builtIn.isNotEmpty
                ? const [SizedBox(width: 6)]
                : const <Widget>[];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children:
              leading
                  ? [...builtIn, ...gap, ...extraWidgets]
                  : [...extraWidgets, ...gap, ...builtIn],
        );
      },
    );
  }

  FloatingDialogButtonSpec _extraSpec(
    BuildContext context,
    FloatingDialogHeaderAction action,
  ) => FloatingDialogButtonSpec(
    tooltip: action.tooltip,
    decoration: action.decoration,
    onPressed: () => action.onPressed(context),
    icon:
        (color, size) => FloatingDialogActionIcon.forHeader(
          icon: action.icon,
          iconBuilder: action.iconBuilder,
          color: color,
          size: size,
        ),
  );

  Widget _extra(
    BuildContext context,
    FloatingDialogHeaderAction action,
    double iconSize,
    double splashRadius,
  ) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.black;
    return IconButton(
      tooltip: action.tooltip,
      splashRadius: splashRadius,
      onPressed: () => action.onPressed(context),
      icon: FloatingDialogActionIcon.forHeader(
        icon: action.icon,
        iconBuilder: action.iconBuilder,
        color: iconColor,
        size: iconSize,
      ),
    );
  }
}
