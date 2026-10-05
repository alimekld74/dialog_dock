import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart' show internal;

import '../controller/floating_dialog_holder_cubit.dart';
import '../host/floating_dialog_host_context.dart';
import '../models/floating_dialog_status.dart';

/// Marks a subtree as the content of the floating window [entryId]. Inserted
/// by the holder; read it with [FloatingDialogScope.maybeOf].
class FloatingDialogScope extends InheritedWidget {
  /// Inserted by the holder around each window.
  @internal
  const FloatingDialogScope({
    super.key,
    required this.entryId,
    required this.holder,
    required this.hasFrame,
    required super.child,
  });

  /// The window's action id.
  final String entryId;

  /// The holder that owns the window.
  final FloatingDialogHolderCubit holder;

  /// Whether the holder already draws the window frame around the content,
  /// so a `FloatingDialogFrame` inside renders its body only.
  final bool hasFrame;

  /// Whether the window is on screen (false while minimized). Not reactive;
  /// check it when an event arrives.
  bool get isActive => holder.state.entryOf(entryId)?.isActive ?? false;

  /// The scope of the window containing [context], or `null` outside one.
  static FloatingDialogScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FloatingDialogScope>();

  /// Closes the window with an optional [result].
  void close([Object? result]) => holder.closeDialog(entryId, result);

  /// Minimizes the window, telling the user when it refuses.
  void minimize(BuildContext context) {
    if (!holder.minimize(entryId)) showFloatingDialogPauseRefused(context);
  }

  @override
  bool updateShouldNotify(FloatingDialogScope oldWidget) =>
      entryId != oldWidget.entryId ||
      holder != oldWidget.holder ||
      hasFrame != oldWidget.hasFrame;
}

/// False while the floating window containing [context] is minimized; true
/// in a regular dialog or page. Minimized windows stay mounted, so listeners
/// of app-wide state can use this to skip events they did not trigger.
bool isFloatingDialogActive(BuildContext context) =>
    FloatingDialogScope.maybeOf(context)?.isActive ?? true;

/// Restores a holder item, telling the user when it is refused.
@internal
void restoreFloatingDialog(BuildContext context, String id) {
  final holder = context.floatingHolder;
  showFloatingDialogStatus(context, holder.restore(id));
}

/// Tells the user why a window was not shown.
@internal
void showFloatingDialogStatus(
  BuildContext context,
  FloatingDialogStatus status,
) {
  final strings = context.floatingStrings;
  final message = switch (status) {
    FloatingDialogStatus.busy => strings.windowBusy,
    FloatingDialogStatus.unavailable ||
    FloatingDialogStatus.notFound => strings.noPermission,
    _ => null,
  };
  if (message != null) context.floatingHost.showMessage(context, message);
}

/// Tells the user a window refused to minimize.
@internal
void showFloatingDialogPauseRefused(BuildContext context) => context
    .floatingHost
    .showMessage(context, context.floatingStrings.cannotPause);

/// Lets dialog content refuse minimizing based on its own state, e.g. while
/// a save is in progress. Does nothing outside a floating window.
///
/// ```dart
/// FloatingDialogPauseGuard(
///   canPause: () => !cubit.state.isSaving,
///   child: content,
/// )
/// ```
class FloatingDialogPauseGuard extends StatefulWidget {
  /// Creates a guard.
  const FloatingDialogPauseGuard({
    super.key,
    required this.canPause,
    required this.child,
  });

  /// Whether the window may be minimized right now.
  final bool Function() canPause;

  /// The dialog content.
  final Widget child;

  @override
  State<FloatingDialogPauseGuard> createState() =>
      _FloatingDialogPauseGuardState();
}

class _FloatingDialogPauseGuardState extends State<FloatingDialogPauseGuard> {
  FloatingDialogScope? _scope;

  bool _canPause() => widget.canPause();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = FloatingDialogScope.maybeOf(context);
    if (scope == _scope) return;
    _scope?.holder.unregisterPauseGuard(_scope!.entryId, _canPause);
    _scope = scope;
    scope?.holder.registerPauseGuard(scope.entryId, _canPause);
  }

  @override
  void dispose() {
    _scope?.holder.unregisterPauseGuard(_scope!.entryId, _canPause);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Keeps a window's content across memory eviction.
///
/// When a minimized window is evicted, [onSave] is called and its value kept
/// in memory. When the user reopens the window, the content is rebuilt and
/// [onRestore] receives that value before [child] builds for the first
/// time. Assign it to your fields or controllers there; don't call
/// `setState`. Nothing is written to disk.
///
/// ```dart
/// FloatingDialogStateKeeper<String>(
///   onSave: () => _note.text,
///   onRestore: (text) => _note.text = text,
///   child: TextField(controller: _note),
/// )
/// ```
///
/// Use one keeper per window. Does nothing outside a floating window.
class FloatingDialogStateKeeper<T extends Object> extends StatefulWidget {
  /// Creates a keeper.
  const FloatingDialogStateKeeper({
    super.key,
    required this.onSave,
    required this.onRestore,
    required this.child,
  });

  /// Returns the state to keep; `null` keeps nothing.
  final T? Function() onSave;

  /// Receives the kept state when the window is rebuilt.
  final void Function(T state) onRestore;

  /// The dialog content.
  final Widget child;

  @override
  State<FloatingDialogStateKeeper<T>> createState() =>
      _FloatingDialogStateKeeperState<T>();
}

class _FloatingDialogStateKeeperState<T extends Object>
    extends State<FloatingDialogStateKeeper<T>> {
  FloatingDialogScope? _scope;

  Object? _save() => widget.onSave();

  @override
  void initState() {
    super.initState();
    final scope = _scope = FloatingDialogScope.maybeOf(context);
    if (scope == null) return;
    final saved = scope.holder.takeSavedState(scope.entryId);
    if (saved is T) widget.onRestore(saved);
    scope.holder.registerStateSaver(scope.entryId, _save);
  }

  @override
  void dispose() {
    _scope?.holder.unregisterStateSaver(_scope!.entryId, _save);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
