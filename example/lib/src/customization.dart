import 'package:dialog_dock/dialog_dock.dart';
import 'package:flutter/material.dart';

/// Icons, header buttons, sizes and window designs.
class CustomizationDemos extends StatelessWidget {
  const CustomizationDemos({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Custom icon + header buttons'),
          onPressed: () => _invoice(context),
        ),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.palette_outlined),
          label: const Text('Your own window design'),
          onPressed: () => _customFrame(context),
        ),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.crop_free),
          label: const Text('No frame, own header'),
          onPressed: () => _frameless(context),
        ),
      ],
    );
  }

  void _invoice(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showFloatingDialog<void>(
      context: context,
      id: 'invoice',
      title: 'Invoice #1042',
      // Any widget as the bubble icon; an SvgPicture works the same way.
      iconBuilder:
          (context, color, size) => Text(
            r'$',
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.w800,
            ),
          ),
      // A smaller window than the default.
      size: const FloatingDialogSizeFactor(width: 0.4, height: 0.5),
      // Only these built-in buttons.
      windowButtons: const {
        FloatingDialogWindowButton.minimize,
        FloatingDialogWindowButton.close,
      },
      // Extra header buttons, each with its own onPressed (and optionally
      // its own decoration).
      headerActions: [
        FloatingDialogHeaderAction(
          tooltip: 'Print',
          icon: Icons.print_outlined,
          onPressed: (context) => _snack(context, 'Printing...'),
        ),
        FloatingDialogHeaderAction(
          tooltip: 'Share',
          icon: Icons.ios_share,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          onPressed: (context) => _snack(context, 'Shared'),
        ),
      ],
      builder: (context) => const Center(child: Text('Total: \$1,280.00')),
    );
  }

  void _customFrame(BuildContext context) => showFloatingDialog<void>(
    context: context,
    id: 'custom-frame',
    title: 'Custom frame',
    icon: Icons.palette_outlined,
    // Draw the whole window yourself; `frame.buttons` keeps the window
    // buttons working.
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

  void _frameless(BuildContext context) => showFloatingDialog<void>(
    context: context,
    id: 'frameless',
    title: 'Frameless',
    icon: Icons.crop_free,
    // The dialog gets the whole window and draws its own header.
    showFrame: false,
    builder:
        (context) => Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const FloatingDialogWindowActions(),
                    const SizedBox(width: 12),
                    Text(
                      'My own header',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const Expanded(child: Center(child: Text('showFrame: false'))),
            ],
          ),
        ),
  );

  static void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(text)));
}
