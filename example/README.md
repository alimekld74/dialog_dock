# dialog_dock example

A gallery of what `dialog_dock` can do:

| File | Shows |
|---|---|
| `lib/main.dart` | The one-time setup: `FloatingDialogHolder` in `MaterialApp.builder` |
| `lib/src/basics.dart` | `showFloatingDialog` with an existing `AlertDialog` and its result, state kept across minimize and eviction, refusing to minimize while busy, dialogs opened from a window |
| `lib/src/customization.dart` | Custom bubble icon, extra header buttons (with their own decoration), window size, your own window design, frameless windows |
| `lib/src/gallery.dart` | `originKey`: windows that grow out of the tapped widget and shrink back |
| `lib/src/look.dart` | Live switches for Liquid Glass, button style, minimize and close effects, dark theme and RTL |

Run it:

```bash
flutter create . --platforms=web,windows,macos,linux,android,ios
flutter run
```
