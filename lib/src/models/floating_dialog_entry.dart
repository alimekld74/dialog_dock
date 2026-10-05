import 'package:equatable/equatable.dart';

/// One window known to the holder. Closed windows are removed; every other
/// window is either mounted (active or minimized) or dormant.
class FloatingDialogEntry extends Equatable {
  /// Creates an entry; produced by the holder.
  const FloatingDialogEntry({
    required this.id,
    this.isActive = true,
    this.isPinned = false,
    this.isLarge = false,
    this.isDormant = false,
    this.minimizedAt,
    this.wasHeld = false,
  });

  /// Saved holder items always come back dormant.
  factory FloatingDialogEntry.fromJson(Map<String, dynamic> json) =>
      FloatingDialogEntry(
        id: json['id'] as String,
        isActive: false,
        isPinned: json['pinned'] == true,
        isLarge: json['large'] == true,
        isDormant: true,
        minimizedAt: DateTime.tryParse(json['minimizedAt'] as String? ?? ''),
        wasHeld: true,
      );

  /// The owning action's id (see `FloatingDialogAction.id`).
  final String id;

  /// Whether this is the window on screen. At most one entry is active.
  final bool isActive;

  /// Pinned windows sit on the screen edge and are never evicted.
  final bool isPinned;

  /// Whether the window is maximized.
  final bool isLarge;

  /// Evicted (expired, over the memory limit, or restored from a previous
  /// app run): no widget in memory. Shown greyed; opening it builds the
  /// dialog again.
  final bool isDormant;

  /// Start of the current minimized period; drives expiry and eviction order.
  final DateTime? minimizedAt;

  /// Has been in the holder at least once. Tapping outside such a window
  /// sends it back instead of closing it.
  final bool wasHeld;

  /// The saved form. [now] stands in for `minimizedAt` of a window that is
  /// still active, so its lifetime counts from when the app was left.
  Map<String, dynamic> toJson(DateTime now) => {
    'id': id,
    'pinned': isPinned,
    'large': isLarge,
    'minimizedAt': (minimizedAt ?? now).toIso8601String(),
  };

  /// Whether the window is in the holder rather than on screen.
  bool get isMinimized => !isActive;

  /// Whether the dialog widget is alive (active or minimized).
  bool get isMounted => !isDormant;

  /// Whether the lifetime applies (minimized and not pinned).
  bool get canExpire => isMinimized && !isPinned;

  /// A copy with the given fields replaced.
  FloatingDialogEntry copyWith({
    bool? isActive,
    bool? isPinned,
    bool? isLarge,
    bool? isDormant,
    DateTime? Function()? minimizedAt,
    bool? wasHeld,
  }) => FloatingDialogEntry(
    id: id,
    isActive: isActive ?? this.isActive,
    isPinned: isPinned ?? this.isPinned,
    isLarge: isLarge ?? this.isLarge,
    isDormant: isDormant ?? this.isDormant,
    minimizedAt: minimizedAt != null ? minimizedAt() : this.minimizedAt,
    wasHeld: wasHeld ?? this.wasHeld,
  );

  @override
  List<Object?> get props => [
    id,
    isActive,
    isPinned,
    isLarge,
    isDormant,
    minimizedAt,
    wasHeld,
  ];
}
