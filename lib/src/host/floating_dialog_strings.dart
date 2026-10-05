/// Every user-facing text of the holder. Defaults are English; pass your own
/// localized instance through `FloatingDialogHostDelegate.strings`.
class FloatingDialogStrings {
  /// Creates the texts; every one has an English default.
  const FloatingDialogStrings({
    this.minimize = 'Minimize',
    this.maximize = 'Maximize',
    this.restoreSize = 'Restore size',
    this.pin = 'Pin',
    this.unpin = 'Unpin',
    this.close = 'Close',
    this.cannotPause = "This window can't be minimized right now.",
    this.windowBusy = 'Minimize or close the open window first.',
    this.noPermission = "You don't have permission to open this.",
    this.pinHint = 'Long-press or right-click to pin',
    this.dormantHint = 'Closed to free memory. Tap to reopen.',
    this.expandHolder = 'Show minimized windows',
    this.collapseHolder = 'Collapse',
    this.settingsTitle = 'Minimized windows',
    this.lifetime = 'Close minimized windows automatically after',
    this.lifetimeHint = 'Pinned windows are never closed automatically.',
    this.custom = 'Custom',
    this.customMinutes = 'Duration in minutes',
    this.invalidMinutes = _invalidMinutes,
    this.minutesCount = _minutesCount,
    this.hoursCount = _hoursCount,
  });

  /// Minimize button tooltip.
  final String minimize;

  /// Maximize button tooltip.
  final String maximize;

  /// Restore-size button tooltip.
  final String restoreSize;

  /// Pin button tooltip.
  final String pin;

  /// Unpin button tooltip.
  final String unpin;

  /// Close button tooltip.
  final String close;

  /// Shown when a window refuses to minimize.
  final String cannotPause;

  /// Shown when opening a window while another one is active.
  final String windowBusy;

  /// Shown when the user lost access to a window.
  final String noPermission;

  /// Holder item tooltip hint about pinning.
  final String pinHint;

  /// Holder item tooltip hint for evicted windows.
  final String dormantHint;

  /// Collapsed holder tooltip.
  final String expandHolder;

  /// Collapse button tooltip.
  final String collapseHolder;

  /// Settings button tooltip and settings dialog title.
  final String settingsTitle;

  /// Lifetime setting label.
  final String lifetime;

  /// Lifetime setting hint.
  final String lifetimeHint;

  /// Custom lifetime choice.
  final String custom;

  /// Custom lifetime field label.
  final String customMinutes;

  /// Custom lifetime validation error.
  final String Function(int min, int max) invalidMinutes;

  /// A lifetime in minutes, e.g. "15 min".
  final String Function(int count) minutesCount;

  /// A lifetime in hours, e.g. "2 h".
  final String Function(int count) hoursCount;

  static String _invalidMinutes(int min, int max) =>
      'Enter a value from $min to $max minutes';
  static String _minutesCount(int count) => '$count min';
  static String _hoursCount(int count) => '$count h';
}
