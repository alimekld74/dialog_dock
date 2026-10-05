/// Minimize dialogs into a floating holder and bring them back with their
/// state intact.
///
/// 1. Wrap your app: `MaterialApp(builder: (context, child) =>
///    FloatingDialogHolder(child: child!))`.
/// 2. Replace `showDialog` with [showFloatingDialog].
library;

export 'src/config/floating_dialog_colors.dart';
export 'src/config/floating_dialog_config.dart';
export 'src/controller/floating_dialog_holder_cubit.dart';
export 'src/host/floating_dialog_host_delegate.dart';
export 'src/host/floating_dialog_storage.dart';
export 'src/host/floating_dialog_strings.dart';
export 'src/models/floating_dialog_action.dart';
export 'src/models/floating_dialog_entry.dart';
export 'src/models/floating_dialog_status.dart';
export 'src/models/floating_dialog_window_frame.dart';
export 'src/view/floating_dialog_frame.dart';
export 'src/view/floating_dialog_holder_widget.dart' show FloatingDialogHolder;
export 'src/view/floating_dialog_scope.dart'
    show
        FloatingDialogPauseGuard,
        FloatingDialogScope,
        FloatingDialogStateKeeper,
        isFloatingDialogActive;
export 'src/view/show_floating_dialog.dart';
export 'src/view/widgets/floating_dialog_settings_dialog.dart'
    show floatingDialogLifetimeLabel, showFloatingDialogSettings;
export 'src/view/widgets/floating_dialog_window_actions.dart';
