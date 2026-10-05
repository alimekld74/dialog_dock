import 'package:flutter/material.dart';

import '../config/floating_dialog_config.dart';
import '../models/floating_dialog_action.dart';
import '../models/floating_dialog_window_frame.dart';
import 'floating_dialog_frame.dart';
import 'floating_dialog_holder_widget.dart';
import 'floating_dialog_scope.dart';

/// Shows a dialog that can be minimized into the floating holder. Use it
/// like `showDialog`; your existing dialog widget works unchanged:
///
/// ```dart
/// final amount = await showFloatingDialog<double>(
///   context: context,
///   id: 'treasury',
///   title: 'Treasury',
///   icon: Icons.account_balance_outlined,
///   builder: (context) => const TreasuryDialog(), // Navigator.pop(context, 42.0)
/// );
/// ```
///
/// * [id] identifies the window: calling this again with the same id while
///   it is held brings that window back (and returns the same result).
/// * Completes with the value passed to `Navigator.pop`, or `null` when the
///   window is closed otherwise. Minimizing does not complete it.
/// * If another window is open, nothing opens, the user is told why, and it
///   completes with `null`.
/// * Without a `FloatingDialogHolder` above [context], falls back to a
///   regular `showDialog`.
///
/// For [icon] use any [IconData], or [iconBuilder] for SVGs and images.
/// [headerActions] adds buttons to the title bar; [frameBuilder] replaces
/// the window chrome. With [originKey] (a `GlobalKey` on the tapped widget)
/// the window grows out of that widget and shrinks back into it, like a
/// `Hero`. See [FloatingDialogAction] for the other parameters.
Future<T?> showFloatingDialog<T>({
  required BuildContext context,
  required String id,
  required String title,
  required WidgetBuilder builder,
  IconData? icon,
  FloatingDialogIconBuilder? iconBuilder,
  List<FloatingDialogHeaderAction> headerActions = const [],
  Set<FloatingDialogWindowButton>? windowButtons,
  FloatingDialogWindowFrameBuilder? frameBuilder,
  bool showFrame = true,
  FloatingDialogSizeFactor? size,
  bool Function()? canPause,
  bool Function()? isAvailable,
  bool isRestorable = false,
  GlobalKey? originKey,
}) => showFloatingDialogAction<T>(
  context,
  FloatingDialogAction(
    id: id,
    title: title,
    builder: builder,
    icon: icon,
    iconBuilder: iconBuilder,
    headerActions: headerActions,
    windowButtons: windowButtons,
    frameBuilder: frameBuilder,
    showFrame: showFrame,
    size: size,
    canPause: canPause,
    isAvailable: isAvailable,
    isRestorable: isRestorable,
    originKey: originKey,
  ),
);

/// [showFloatingDialog] for a prebuilt [FloatingDialogAction].
Future<T?> showFloatingDialogAction<T>(
  BuildContext context,
  FloatingDialogAction action,
) {
  final holder = FloatingDialogHolder.maybeOf(context);
  if (holder == null) {
    return showDialog<T>(
      context: context,
      builder:
          (context) =>
              action.showFrame
                  ? FloatingDialogFrame(
                    title: action.title,
                    headerActions: action.headerActions,
                    frameBuilder: action.frameBuilder,
                    child: action.builder(context),
                  )
                  : action.builder(context),
    );
  }
  final handle = holder.open<T>(action);
  if (!handle.status.isShown) showFloatingDialogStatus(context, handle.status);
  return handle.result;
}
