import 'package:flutter/material.dart';

import '../config/floating_dialog_config.dart';
import '../view/floating_dialog_frame.dart';
import 'floating_dialog_storage.dart';
import 'floating_dialog_strings.dart';

/// Device class; picks window sizes, item sizes and holder placement.
enum FloatingDialogDeviceType {
  /// Phone: near full-screen windows, holder at the bottom-start corner.
  mobile,

  /// Tablet: touch-sized items and a wider tap area on the pinned dock.
  tablet,

  /// Desktop / web with a mouse.
  desktop,
}

/// Builds the dialog chrome for the holder's own settings dialog.
typedef FloatingDialogFrameBuilder =
    Widget Function(
      BuildContext context, {
      required String title,
      required Widget child,
      double? width,
    });

/// App-specific hooks: storage, current user, messages, texts. Every member
/// has a working default, so `FloatingDialogHostDelegate()` runs as is.
class FloatingDialogHostDelegate {
  /// Creates the hooks; everything is optional.
  FloatingDialogHostDelegate({
    FloatingDialogStorage? storage,
    this.userId = _singleUser,
    this.showMessage = _snackBar,
    this.deviceType,
    this.strings = _englishStrings,
    this.frameBuilder = _defaultFrame,
  }) : storage = storage ?? InMemoryFloatingDialogStorage();

  /// Lifetime setting and saved item list. Defaults to memory only; use
  /// [KeyValueFloatingDialogStorage] to keep them across restarts.
  final FloatingDialogStorage storage;

  /// Owner of the saved list (a JSON value, e.g. the user id). Another owner
  /// never sees it; `null` disables saving (e.g. nobody logged in).
  final Object? Function() userId;

  /// Shows feedback such as "can't minimize right now". Defaults to a
  /// SnackBar.
  final void Function(BuildContext context, String message) showMessage;

  /// Device class; defaults to width breakpoints from the config.
  final FloatingDialogDeviceType Function(BuildContext context)? deviceType;

  /// Texts; return your localized [FloatingDialogStrings] here.
  final FloatingDialogStrings Function(BuildContext context) strings;

  /// Dialog chrome of the holder's own settings dialog.
  final FloatingDialogFrameBuilder frameBuilder;

  static Object? _singleUser() => 'default';

  static void _snackBar(BuildContext context, String message) =>
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));

  static FloatingDialogStrings _englishStrings(BuildContext context) =>
      const FloatingDialogStrings();

  static Widget _defaultFrame(
    BuildContext context, {
    required String title,
    required Widget child,
    double? width,
  }) => FloatingDialogFrame(title: title, width: width, child: child);

  /// Device class from the screen width and [config]'s breakpoints.
  static FloatingDialogDeviceType defaultDeviceType(
    BuildContext context, [
    FloatingDialogConfig config = const FloatingDialogConfig(),
  ]) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= config.mobileMaxWidth) return FloatingDialogDeviceType.mobile;
    if (width <= config.tabletMaxWidth) return FloatingDialogDeviceType.tablet;
    return FloatingDialogDeviceType.desktop;
  }
}
