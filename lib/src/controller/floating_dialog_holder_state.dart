part of 'floating_dialog_holder_cubit.dart';

/// Snapshot of the holder: its windows, the actions it shows, and settings.
class FloatingDialogHolderState extends Equatable {
  /// Creates a snapshot; produced by the holder.
  const FloatingDialogHolderState({
    this.entries = const [],
    this.actions = const {},
    this.isExpanded = true,
    this.lifetime = const Duration(minutes: 15),
  });

  /// Every known window, in opening order.
  final List<FloatingDialogEntry> entries;

  /// Actions currently known to the holder. Items whose action is unknown
  /// (saved, not registered yet) are kept but hidden. Compared by id, title
  /// and icon only; use `FloatingDialogHolderCubit.actionOf` for the latest
  /// instance.
  final Map<String, FloatingDialogAction> actions;

  /// Whether the holder bar is expanded.
  final bool isExpanded;

  /// Lifetime of minimized, unpinned windows.
  final Duration lifetime;

  /// The entry for [id], if any.
  FloatingDialogEntry? entryOf(String id) =>
      entries.firstWhereOrNull((e) => e.id == id);

  /// The action shown for [id], if any.
  FloatingDialogAction? actionOf(String id) => actions[id];

  /// The window on screen, if any.
  FloatingDialogEntry? get activeEntry =>
      entries.firstWhereOrNull((e) => e.isActive);

  /// Whether the active window is maximized (the holder then hides).
  bool get isLargeWindowActive => activeEntry?.isLarge ?? false;

  /// Ids of windows whose dialog widget is alive (active or minimized).
  List<String> get mountedIds =>
      entries.where((e) => e.isMounted).map((e) => e.id).toList();

  bool _isShown(FloatingDialogEntry e) =>
      e.isMinimized && actions.containsKey(e.id);

  /// Minimized or dormant, unpinned windows shown in the holder bar.
  List<FloatingDialogEntry> get heldEntries =>
      entries.where((e) => _isShown(e) && !e.isPinned).toList();

  /// Minimized or dormant, pinned windows shown on the screen edge.
  List<FloatingDialogEntry> get pinnedEntries =>
      entries.where((e) => _isShown(e) && e.isPinned).toList();

  /// A copy with the given fields replaced.
  FloatingDialogHolderState copyWith({
    List<FloatingDialogEntry>? entries,
    Map<String, FloatingDialogAction>? actions,
    bool? isExpanded,
    Duration? lifetime,
  }) => FloatingDialogHolderState(
    entries: entries ?? this.entries,
    actions: actions ?? this.actions,
    isExpanded: isExpanded ?? this.isExpanded,
    lifetime: lifetime ?? this.lifetime,
  );

  @override
  List<Object?> get props => [
    entries,
    [
      for (final a in actions.values)
        (a.id, a.title, a.icon, a.iconBuilder == null),
    ],
    isExpanded,
    lifetime,
  ];
}
