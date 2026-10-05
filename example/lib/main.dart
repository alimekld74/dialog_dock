import 'package:dialog_dock/dialog_dock.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  ThemeMode _mode = ThemeMode.light;
  TextDirection _direction = TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Floating dialogs',
      themeMode: _mode,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        // Optional: per-theme holder colors.
        extensions: const [FloatingDialogColors(dockClose: Colors.deepOrange)],
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      // 1. Wrap the app once.
      builder:
          (context, child) => Directionality(
            textDirection: _direction,
            child: FloatingDialogHolder(
              config: const FloatingDialogConfig(maxMountedWindows: 5),
              child: child!,
            ),
          ),
      home: HomePage(
        onToggleTheme:
            () => setState(
              () =>
                  _mode =
                      _mode == ThemeMode.light
                          ? ThemeMode.dark
                          : ThemeMode.light,
            ),
        onToggleDirection:
            () => setState(
              () =>
                  _direction =
                      _direction == TextDirection.ltr
                          ? TextDirection.rtl
                          : TextDirection.ltr,
            ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onToggleTheme,
    required this.onToggleDirection,
  });

  final VoidCallback onToggleTheme;
  final VoidCallback onToggleDirection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Floating dialogs'),
        actions: [
          IconButton(
            tooltip: 'Theme',
            onPressed: onToggleTheme,
            icon: const Icon(Icons.brightness_6),
          ),
          IconButton(
            tooltip: 'Direction',
            onPressed: onToggleDirection,
            icon: const Icon(Icons.format_textdirection_r_to_l),
          ),
        ],
      ),
      body: Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(
              onPressed: () => _openExistingDialog(context),
              child: const Text('Existing AlertDialog'),
            ),
            FilledButton(
              onPressed: () => _openNotes(context),
              child: const Text('Notes (custom icon, header action)'),
            ),
            FilledButton(
              onPressed: () => _openCustomFrame(context),
              child: const Text('Custom frame'),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Replace showDialog with showFloatingDialog. The dialog is unchanged.
  Future<void> _openExistingDialog(BuildContext context) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      id: 'confirm',
      title: 'Delete item',
      icon: Icons.delete_outline,
      builder:
          (context) => AlertDialog(
            content: const Text('Minimize me, browse around, come back.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (context.mounted && confirmed != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Confirmed: $confirmed')));
    }
  }

  void _openNotes(BuildContext context) {
    showFloatingDialog<void>(
      context: context,
      id: 'notes',
      title: 'Notes',
      // Any widget works here, e.g. SvgPicture.asset(..., colorFilter: ...).
      iconBuilder:
          (context, color, size) => Text(
            'N',
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.bold,
            ),
          ),
      headerActions: [
        FloatingDialogHeaderAction(
          tooltip: 'Clear',
          icon: Icons.clear_all,
          onPressed:
              (context) => ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(const SnackBar(content: Text('Clear tapped'))),
        ),
      ],
      builder: (context) => const NotesDialog(),
    );
  }

  void _openCustomFrame(BuildContext context) {
    showFloatingDialog<void>(
      context: context,
      id: 'custom',
      title: 'Custom frame',
      icon: Icons.palette_outlined,
      windowButtons: const {
        FloatingDialogWindowButton.minimize,
        FloatingDialogWindowButton.close,
      },
      frameBuilder:
          (context, frame) => Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(frame.title),
                  trailing: frame.buttons,
                ),
                const Divider(height: 1),
                Expanded(child: frame.body),
              ],
            ),
          ),
      builder:
          (context) => const Center(child: Text('Any header, shape or color.')),
    );
  }
}

/// Keeps its text when minimized, and even when evicted to save memory.
class NotesDialog extends StatefulWidget {
  const NotesDialog({super.key});

  @override
  State<NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<NotesDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingDialogStateKeeper<String>(
      onSave: () => _text.text,
      onRestore: (text) => _text.text = text,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: TextField(
          controller: _text,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            hintText: 'Type, minimize, come back...',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
