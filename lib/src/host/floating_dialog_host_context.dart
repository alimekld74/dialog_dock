// Internal: not exported from the package.
// ignore_for_file: public_member_api_docs

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/floating_dialog_colors.dart';
import '../config/floating_dialog_config.dart';
import '../controller/floating_dialog_holder_cubit.dart';
import 'floating_dialog_host_delegate.dart';
import 'floating_dialog_strings.dart';

/// Internal shortcuts to the holder's settings (not exported).
extension FloatingDialogHostContext on BuildContext {
  FloatingDialogHolderCubit get floatingHolder =>
      read<FloatingDialogHolderCubit>();

  FloatingDialogHostDelegate get floatingHost => floatingHolder.host;

  FloatingDialogConfig get floatingConfig => floatingHolder.config;

  FloatingDialogColors get floatingColors =>
      FloatingDialogColors.resolve(this, floatingConfig.colors);

  FloatingDialogStrings get floatingStrings => floatingHost.strings(this);

  FloatingDialogDeviceType get floatingDevice =>
      floatingHost.deviceType?.call(this) ??
      FloatingDialogHostDelegate.defaultDeviceType(this, floatingConfig);

  bool get isFloatingMobile =>
      floatingDevice == FloatingDialogDeviceType.mobile;

  bool get isFloatingTablet =>
      floatingDevice == FloatingDialogDeviceType.tablet;

  bool get isFloatingDesktop =>
      floatingDevice == FloatingDialogDeviceType.desktop;
}
