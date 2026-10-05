import 'dart:async';

import 'package:dialog_dock/dialog_dock.dart';
import 'package:flutter/material.dart';

/// STEP 2: showFloatingDialog instead of showDialog. Dialog widgets work
/// unchanged, and `Navigator.pop(context, value)` returns the value.
class BasicsDemos extends StatelessWidget {
  const BasicsDemos({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('An existing AlertDialog'),
          onPressed: () => _confirm(context),
        ),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.edit_note),
          label: const Text('Notes that keep their text'),
          onPressed: () => _notes(context),
        ),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text("Can't minimize while uploading"),
          onPressed: () => _upload(context),
        ),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.layers_outlined),
          label: const Text('Dialog inside a window'),
          onPressed: () => _nested(context),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final deleted = await showFloatingDialog<bool>(
      context: context,
      id: 'confirm', // one window per id
      title: 'Delete item',
      icon: Icons.delete_outline, // shown on the bubble
      builder:
          (context) => AlertDialog(
            content: const Text(
              'Minimize me, look around the app, then come back.',
            ),
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (deleted) {
          true => 'Deleted',
          false => 'Cancelled',
          null => 'Closed without an answer',
        }),
      ),
    );
  }

  void _notes(BuildContext context) => showFloatingDialog<void>(
    context: context,
    id: 'notes',
    title: 'Notes',
    icon: Icons.edit_note,
    builder: (context) => const _NotesDialog(),
  );

  void _upload(BuildContext context) => showFloatingDialog<void>(
    context: context,
    id: 'upload',
    title: 'Upload',
    icon: Icons.cloud_upload_outlined,
    builder: (context) => const _UploadDialog(),
  );

  void _nested(BuildContext context) => showFloatingDialog<void>(
    context: context,
    id: 'nested',
    title: 'Settings',
    icon: Icons.tune,
    builder:
        (context) => Center(
          child: FilledButton(
            // A regular showDialog opens above the window; Back closes it
            // first, then the window.
            onPressed:
                () => showDialog<void>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Reset settings?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                ),
            child: const Text('Open a normal dialog'),
          ),
        ),
  );
}

/// Minimized windows stay alive. To survive eviction too (lifetime or
/// memory limit), save the text with a [FloatingDialogStateKeeper].
class _NotesDialog extends StatefulWidget {
  const _NotesDialog();

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
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

/// [FloatingDialogPauseGuard] refuses minimizing while work is running.
class _UploadDialog extends StatefulWidget {
  const _UploadDialog();

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  double? _progress;
  Timer? _timer;

  void _start() {
    setState(() => _progress = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      setState(() => _progress = _progress! + 0.02);
      if (_progress! >= 1) {
        timer.cancel();
        setState(() => _progress = null);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploading = _progress != null;
    return FloatingDialogPauseGuard(
      canPause: () => !uploading,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              uploading
                  ? 'Uploading: try to minimize now'
                  : 'Start an upload, then try to minimize.',
            ),
            const SizedBox(height: 16),
            if (uploading)
              SizedBox(
                width: 240,
                child: LinearProgressIndicator(value: _progress),
              )
            else
              FilledButton(onPressed: _start, child: const Text('Upload')),
          ],
        ),
      ),
    );
  }
}
