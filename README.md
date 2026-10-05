# dialog_dock

Minimize Flutter dialogs instead of closing them. A minimized dialog becomes
a small bubble in the corner of the app; tapping it brings the dialog back
exactly as it was: typed text, scroll position, open tabs, everything.

It's a drop-in for `showDialog`: your existing dialog widgets work unchanged.

- Minimize, pin, maximize and close buttons on every window
- Bubbles in a collapsible holder; pinned windows on the screen edge
- macOS-style Genie minimize, and Hero-style open/close from the tapped widget
- `Navigator.pop(context, result)` returns the result, like `showDialog`
- Dialogs opened from a window stay above it
- Back (Android, browser) and Esc dismiss the window, never the page below
- Keyboard focus stays in the window and returns to the app afterwards
- Memory limit and lifetime for minimized windows, with optional state saving
- Custom colors, icons (including SVG), header buttons and window design
- Light / dark themes, RTL, phones, tablets and desktop; all platforms

## Quick start

```yaml
dependencies:
  dialog_dock: ^0.1.0
```

**1. Wrap your app once:**

```dart
MaterialApp(
  builder: (context, child) => FloatingDialogHolder(child: child!),
  home: const HomePage(),
);
```

**2. Replace `showDialog` with `showFloatingDialog`:**

```dart
final confirmed = await showFloatingDialog<bool>(
  context: context,
  id: 'delete-item',          // one window per id
  title: 'Delete item',
  icon: Icons.delete_outline, // shown on the bubble
  builder: (context) => const MyExistingDialog(), // unchanged
);
```

That's it. There is no controller, provider or state management to set up.

## How it behaves

| State | Dialog in memory | Shown as |
|---|---|---|
| **Open** | yes | the window, above a barrier |
| **Minimized** | yes, paused (animations stopped, no focus) | a bubble |
| **Evicted** (lifetime ended or memory limit) | no | a greyed bubble; tap reopens it fresh |
| **Closed** | no | removed |

- **One window per id.** Opening an id that is already minimized brings
  that window back and returns the same result future.
- **One open window at a time.** Opening another while one is open is
  refused, and the user is asked to minimize or close the first.
- **Tapping outside, Back or Esc** closes a new window: it drops towards the
  bottom of the screen. A window that was minimized before, or is pinned,
  goes back to the holder (pinned: to the edge dock) instead.
- **The result** completes with the value given to `Navigator.pop`, or `null`
  when closed otherwise. Minimizing and eviction don't complete it.
- **Without a `FloatingDialogHolder`** above the context,
  `showFloatingDialog` falls back to a normal `showDialog`.

## Existing dialogs

Dialog widgets work unchanged inside a window:

- `Navigator.pop(context, value)` closes the window with that value.
- `showDialog` from inside the window opens above it; Back closes it first.
- `AlertDialog` / `Dialog` blend into the window (no second card).
- `FloatingDialogFrame` shows only its body inside a window, so the same
  widget can also be used with `showDialog`.

Minimized windows stay mounted. If a dialog listens to app-wide state, skip
events while it's minimized:

```dart
if (!isFloatingDialogActive(context)) return;
```

Dialog routes don't see providers scoped to a page, and the same is true
here. Pass blocs in, as you would for `showDialog`:

```dart
final cubit = context.read<InvoiceCubit>();
showFloatingDialog(
  context: context,
  id: 'invoice',
  title: 'Invoice',
  builder: (_) => BlocProvider.value(value: cubit, child: const InvoiceDialog()),
);
```

## Refusing to minimize

```dart
showFloatingDialog(
  ...,
  canPause: () => !payment.isProcessing,
);

// Or from inside the dialog, based on its own state:
FloatingDialogPauseGuard(
  canPause: () => !cubit.state.isSaving,
  child: content,
);
```

## Animations

Windows animate like macOS:

- **Minimize** pours the window into its bubble with the Dock's **Genie**
  effect; **restore** plays it backwards. Choose `scale` (the Dock's Scale
  effect) or `fade` instead:
  `FloatingDialogConfig(minimizeEffect: FloatingDialogMinimizeEffect.scale)`.
- **Open** zooms in; **close** drops towards the bottom center of the
  screen while shrinking and fading. For a fade in place instead:
  `FloatingDialogConfig(closeEffect: FloatingDialogCloseEffect.fade)`.
- **Like a Hero:** give the tapped widget a `GlobalKey` and pass it as
  `originKey`. The window grows out of that widget and shrinks back into it
  when closed.

```dart
final photoKey = GlobalKey();

GestureDetector(
  onTap: () => showFloatingDialog(
    context: context,
    id: 'photo-1',
    title: 'Photo',
    originKey: photoKey,
    builder: (_) => Image.asset('assets/photo.jpg'),
  ),
  child: Image.asset('assets/photo.jpg', key: photoKey, width: 96),
);
```

Durations: `minimizeEffectDuration`, `openEffectDuration`,
`closeEffectDuration` (zero turns one off). All effects are skipped when
the platform asks to reduce motion.

## Memory and eviction

Minimized, unpinned windows are evicted (disposed, bubble greyed) when:

- their **lifetime** ends (default 15 minutes; users can change it from the
  holder's settings button), or
- more than **`maxMountedWindows`** (default 10) are minimized. The least
  recently minimized one goes first.

Pinned windows are never evicted. To keep content across eviction, wrap it
in a `FloatingDialogStateKeeper` (memory only, nothing is written to disk):

```dart
FloatingDialogStateKeeper<String>(
  onSave: () => _note.text,
  onRestore: (text) => _note.text = text,
  child: TextField(controller: _note),
)
```

## Customization

### Icons (IconData, SVG, images)

```dart
showFloatingDialog(
  ...,
  iconBuilder: (context, color, size) => SvgPicture.asset(
    'assets/treasury.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  ),
);
```

### Liquid Glass

```dart
FloatingDialogHolder(
  config: const FloatingDialogConfig(liquidGlass: true),
  child: child!,
);
```

Windows, the holder bar and the dock become macOS-style frosted glass with
a light rim; the header blends into the window.

### Window buttons

By default the built-in buttons are macOS traffic lights on the leading
side (close, minimize, maximize, pin) with a centered title. Hovering
magnifies them like the Dock.

```dart
const FloatingDialogConfig(
  windowButtonStyle: FloatingDialogWindowButtonStyle.tonal, // or plain
  windowButtonsPlacement: FloatingDialogWindowButtonsPlacement.trailing,
  windowButtonSize: 18,
  windowButtonHoverScale: 1.4,
  headerHeight: 56,
  // A background for every built-in button:
  windowButtonDecoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
  // Or replace a button completely (shown as is, no decoration):
  windowButtonIcons: FloatingDialogWindowButtonIcons(
    minimize: MyMinimizeSvg(),
    close: MyCloseSvg(),
  ),
);
```

Header actions take their own `decoration`, which replaces the style's:

```dart
FloatingDialogHeaderAction(
  tooltip: 'Print',
  icon: Icons.print_outlined,
  decoration: BoxDecoration(color: Colors.teal.shade100, shape: BoxShape.circle),
  onPressed: (context) => printInvoice(),
);
```

### Extra header buttons, and which built-in ones to show

```dart
showFloatingDialog(
  ...,
  headerActions: [
    FloatingDialogHeaderAction(
      tooltip: 'Print',
      icon: Icons.print_outlined,
      onPressed: (context) => printInvoice(),
    ),
  ],
  windowButtons: {
    FloatingDialogWindowButton.minimize,
    FloatingDialogWindowButton.close,
  },
);
```

### Colors

Every color defaults to your `ColorScheme`. Override some for all themes:

```dart
FloatingDialogHolder(
  config: const FloatingDialogConfig(
    colors: FloatingDialogColors(headerBackground: Colors.teal),
  ),
  child: child!,
);
```

Or per theme, as a theme extension:

```dart
ThemeData(extensions: const [
  FloatingDialogColors(item: Colors.orange, barrier: Colors.black38),
]);
```

Available: `headerBackground`, `headerForeground`, `windowBackground`,
`barrier`, `holderBackground`, `holderBorder`, `holderShadow`, `item`,
`dimmedItem`, `badgeBackground`, `badgeForeground`, `dockIndicator`,
`dockClose`.

### Window design

Simple tweaks go in the config: `headerTextStyle`, `headerHeight`,
`frameShape`, `frameRadius`, `headerPadding`, `windowElevation` and sizes. To draw your own
header, shape or background, use a frame builder, either for every window
(`FloatingDialogConfig.windowFrameBuilder`) or for one dialog:

```dart
showFloatingDialog(
  ...,
  frameBuilder: (context, frame) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      ListTile(title: Text(frame.title), trailing: frame.buttons),
      Expanded(child: frame.body),
    ]),
  ),
);
```

`frame.buttons` holds your header actions and the window buttons. Set
`showFrame: false` to give the dialog the whole window, and put
`FloatingDialogWindowActions()` in its own header.

### Everything else

Pinned windows sit on the screen edge as a thin indicator that expands on
hover or tap, on every device. To always show them:
`FloatingDialogConfig(dockAlwaysExpanded: true)`.

`FloatingDialogConfig` holds sizes (per device), holder placement
(`holderBottomOffset` to clear a bottom bar), animation timings, lifetime
presets, the memory limit, breakpoints and keyboard shortcuts
(`dismissShortcut` = Esc, `minimizeShortcut` = Ctrl+M).

## Texts and localization

```dart
FloatingDialogHolder(
  host: FloatingDialogHostDelegate(
    strings: (context) => FloatingDialogStrings(
      minimize: context.l10n.minimize,
      // ...
    ),
  ),
  child: child!,
);
```

`FloatingDialogHostDelegate` also takes `showMessage` (defaults to a
SnackBar) and `deviceType` (defaults to width breakpoints).

## Keeping bubbles across restarts (optional)

Off by default. To bring minimized windows back (greyed) after a restart,
give the holder storage and a user, mark dialogs `isRestorable: true`, and
register them on start so the holder knows how to rebuild them:

```dart
final prefs = await SharedPreferences.getInstance();

FloatingDialogHolder(
  host: FloatingDialogHostDelegate(
    storage: KeyValueFloatingDialogStorage(
      readString: prefs.getString,
      writeString: prefs.setString,
    ),
    userId: () => auth.currentUser?.id, // null disables saving
  ),
  child: child!,
);

// After login, with the dialogs this user may open:
FloatingDialogHolder.of(context).registerActions([
  FloatingDialogAction(
    id: 'treasury',
    title: 'Treasury',
    icon: Icons.account_balance_outlined,
    isRestorable: true,
    builder: (_) => const TreasuryDialog(),
  ),
]);
```

Only ids, flags and times are stored, never dialog content.

## Permissions

`isAvailable` is checked before every restore. Pass `availabilityChanges`
(any `Listenable`) to re-check every window when permissions change; windows
that lost access are closed:

```dart
FloatingDialogHolder(availabilityChanges: permissions, child: child!);

showFloatingDialog(..., isAvailable: () => permissions.can('treasury'));
```

## Advanced

- `FloatingDialogHolder.of(context)` returns the controller: `open`,
  `restore`, `minimize`, `closeDialog(id, result)`, `togglePin`,
  `toggleSize`, `setLifetime`, `registerActions`.
- Pass `controller:` to create and own it yourself (tests, DI).
- Place the holder inside a route instead of `MaterialApp.builder` if
  windows should only live on part of the app; Back handling still works.
- Pass `navigatorKey:` if the holder can't find your app's navigator.

## Platform notes

Works on Android, iOS, web, Windows, macOS and Linux. Minimized windows stay
mounted, so they keep their memory until evicted; tune `maxMountedWindows`
for heavy dialogs.
