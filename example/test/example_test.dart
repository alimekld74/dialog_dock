import 'package:dialog_dock/dialog_dock.dart';
import 'package:dialog_dock_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const s = FloatingDialogStrings();

void main() {
  testWidgets('every demo opens, minimizes and closes', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    Future<void> openAndClose(Finder button, {bool minimize = true}) async {
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      if (minimize && find.byTooltip(s.minimize).evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip(s.minimize).first);
        await tester.pumpAndSettle();
        await tester.tap(button); // restores the same window
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip(s.close).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$button');
    }

    for (final label in [
      'An existing AlertDialog',
      'Notes that keep their text',
      "Can't minimize while uploading",
      'Dialog inside a window',
      'Custom icon + header buttons',
      'Your own window design',
    ]) {
      await openAndClose(find.text(label));
    }
    // Frameless: buttons come from FloatingDialogWindowActions.
    await openAndClose(find.text('No frame, own header'));

    // Gallery tile.
    final tile = find.descendant(
      of: find.byType(GestureDetector),
      matching: find.byType(Container),
    );
    expect(tile, findsWidgets);

    // Look switches.
    for (final label in ['Liquid Glass', 'Dark theme', 'Right to left']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    for (final seg in ['tonal', 'plain', 'scale', 'fade']) {
      await tester.ensureVisible(find.text(seg).first);
      await tester.tap(find.text(seg).first);
      await tester.pumpAndSettle();
    }
    await openAndClose(find.text('An existing AlertDialog'));
    expect(tester.takeException(), isNull);
  });
}
