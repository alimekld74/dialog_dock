## 0.1.3

- Fix: a `FloatingDialogHolder` inside another one (for example around a
  single page) now reuses the outer holder. Before, both holders showed a
  bar, and windows minimized on that page disappeared when leaving it.

## 0.1.2

- The holder bar can be dragged anywhere on the screen. The spot is kept in
  memory while the app runs and resets to the corner on restart. Turn it off
  with `FloatingDialogConfig(holderDraggable: false)`.

## 0.1.1

- Screenshots on pub.dev and in the README (desktop, mobile, dark mode,
  RTL, customization).

## 0.1.0

First public release.

- `FloatingDialogHolder`: wrap the app once (`MaterialApp.builder`); no
  controller or provider setup.
- `showFloatingDialog<T>`: drop-in for `showDialog` that returns the
  `Navigator.pop` result. Falls back to `showDialog` without a holder.
- Each window has its own navigator: existing dialogs work unchanged, and
  dialogs opened from a window stay above it.
- Back (Android, browser) and Esc dismiss the window, never the page below;
  Ctrl+M minimizes. Both shortcuts are configurable.
- Focus is trapped in the open window and restored afterwards; screen
  readers can't reach the app behind it.
- Memory: `maxMountedWindows` evicts the least recently minimized window;
  `FloatingDialogStateKeeper` saves content across eviction.
- Customization: `FloatingDialogColors` (config or theme extension),
  `iconBuilder` for SVG/image icons, `headerActions`, `windowButtons`,
  `frameBuilder` / `windowFrameBuilder`, `headerTextStyle`, `frameShape`.
  Every value in `FloatingDialogConfig` is overridable.
- macOS-style animations: Genie (or Scale / fade) minimize into the bubble
  and back, zoom-in open, and a close that drops towards the bottom center
  (`closeEffect`, or fade). Tapping outside a pinned window sends it to the
  pinned dock instead of closing it. `originKey` makes a window grow
  out of, and shrink back into, the widget it was opened from (like a
  Hero). Respects reduce motion.
- The pinned dock collapses to a thin indicator on every device (expands on
  hover or tap), scrolls instead of overflowing and stays clear of the
  holder bar. `dockAlwaysExpanded: true` keeps it open.
- Window design: `liquidGlass` (macOS-style frosted glass windows, holder
  bar and dock); `windowButtonStyle` (macOS traffic lights by default, with
  Dock-style hover magnification, or tonal / plain);
  `windowButtonsPlacement`, `windowButtonSize`, `windowButtonHoverScale`,
  `windowButtonDecoration`, `windowButtonIcons` (replace any built-in
  button) and `headerHeight`. Header actions take a `decoration`.
- Storage: `KeyValueFloatingDialogStorage` works with SharedPreferences or
  any key-value store; no plugin dependency.

### Migrating from the internal version

- `BlocProvider(create: FloatingDialogHolderCubit(...))` +
  `FloatingDialogLayer` → `FloatingDialogHolder(...)` in `MaterialApp.builder`.
- `cubit.open(action)` returns a `FloatingDialogHandle` (status + result)
  instead of `bool`; `restore` returns a `FloatingDialogStatus`.
- `syncActions` → `registerActions`.
- `closeHostDialog(context)` → `Navigator.pop(context)`;
  `isHostDialogActive` → `isFloatingDialogActive`;
  `dialogHostContext` is no longer needed.
- `FloatingDialogConfig` is now an instance; pass the old values
  (e.g. `holderBottomOffset: 72`) to `FloatingDialogHolder(config: ...)`.
- `FloatingDialogAction.isRestorable` now defaults to `false`.
- `SharedPreferencesFloatingDialogStorage` →
  `KeyValueFloatingDialogStorage(readString: prefs.getString,
  writeString: prefs.setString)`. The lifetime is now stored as a string,
  so a previously saved lifetime falls back to the default once.
