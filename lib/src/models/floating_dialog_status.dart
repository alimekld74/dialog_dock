/// Outcome of opening or restoring a floating dialog.
enum FloatingDialogStatus {
  /// A new window was opened.
  opened,

  /// The existing window for this id was brought back (or already active).
  restored,

  /// Another window is active; minimize or close it first.
  busy,

  /// The action's `isAvailable` returned false.
  unavailable,

  /// No window or action is known for this id.
  notFound;

  /// Whether the window is now on screen.
  bool get isShown => this == opened || this == restored;
}

/// What `FloatingDialogHolderCubit.open` returns: whether the window is shown,
/// and the value it is eventually closed with.
class FloatingDialogHandle<T> {
  /// Creates a handle; produced by the holder.
  const FloatingDialogHandle(this.status, this.result);

  /// Whether the window opened, and if not, why.
  final FloatingDialogStatus status;

  /// Completes when the window is closed: with the value passed to
  /// `Navigator.pop` / `closeDialog`, or `null` when it is closed otherwise
  /// (close button, tap outside a new window, revoked access, holder
  /// disposed). Minimizing and memory eviction do not complete it. Completes
  /// with `null` right away when the window was not shown.
  final Future<T?> result;
}
