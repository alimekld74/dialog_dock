// dialog_dock example: a gallery of what the package can do.
//
// The whole setup is two steps:
//   1. Wrap your app once with FloatingDialogHolder (see `builder` below).
//   2. Call showFloatingDialog where you used showDialog (see src/basics.dart).
import 'package:dialog_dock/dialog_dock.dart';
import 'package:flutter/material.dart';

import 'src/basics.dart';
import 'src/customization.dart';
import 'src/gallery.dart';
import 'src/look.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  Look _look = const Look();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dialog_dock',
      debugShowCheckedModeBanner: false,
      themeMode: _look.dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      // STEP 1: wrap the app once. No controller or provider to set up.
      builder:
          (context, child) => Directionality(
            textDirection: _look.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: FloatingDialogHolder(
              // The config is read once; a new key applies a new look.
              key: ValueKey(_look.configKey),
              config: _look.toConfig(),
              child: child!,
            ),
          ),
      home: HomePage(
        look: _look,
        onLookChanged: (look) => setState(() => _look = look),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.look, required this.onLookChanged});

  final Look look;
  final ValueChanged<Look> onLookChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('dialog_dock')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const Section(
            title: 'Basics',
            subtitle:
                'Minimize (yellow), pin (blue) or close (red) a window. '
                'Tap its bubble in the corner to bring it back.',
            child: BasicsDemos(),
          ),
          const Section(
            title: 'Customization',
            subtitle: 'Icons, header buttons and your own window design.',
            child: CustomizationDemos(),
          ),
          const Section(
            title: 'Like a Hero',
            subtitle: 'The window grows out of the tile and shrinks back.',
            child: GalleryDemo(),
          ),
          Section(
            title: 'Look',
            subtitle: 'Changing the look restarts the holder.',
            child: LookPanel(look: look, onChanged: onLookChanged),
          ),
        ],
      ),
    );
  }
}

/// A titled card on the home page.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
