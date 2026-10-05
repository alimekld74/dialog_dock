import 'package:dialog_dock/dialog_dock.dart';
import 'package:flutter/material.dart';

/// The example's appearance settings, turned into a [FloatingDialogConfig].
@immutable
class Look {
  const Look({
    this.dark = false,
    this.rtl = false,
    this.liquidGlass = true,
    this.buttons = FloatingDialogWindowButtonStyle.trafficLights,
    this.minimize = FloatingDialogMinimizeEffect.genie,
    this.close = FloatingDialogCloseEffect.slideDown,
  });

  final bool dark;
  final bool rtl;
  final bool liquidGlass;
  final FloatingDialogWindowButtonStyle buttons;
  final FloatingDialogMinimizeEffect minimize;
  final FloatingDialogCloseEffect close;

  /// Changes when [toConfig] changes (theme and direction don't need a
  /// new holder).
  Object get configKey => (liquidGlass, buttons, minimize, close);

  FloatingDialogConfig toConfig() => FloatingDialogConfig(
    liquidGlass: liquidGlass,
    windowButtonStyle: buttons,
    minimizeEffect: minimize,
    closeEffect: close,
    maxMountedWindows: 5,
  );

  Look copyWith({
    bool? dark,
    bool? rtl,
    bool? liquidGlass,
    FloatingDialogWindowButtonStyle? buttons,
    FloatingDialogMinimizeEffect? minimize,
    FloatingDialogCloseEffect? close,
  }) => Look(
    dark: dark ?? this.dark,
    rtl: rtl ?? this.rtl,
    liquidGlass: liquidGlass ?? this.liquidGlass,
    buttons: buttons ?? this.buttons,
    minimize: minimize ?? this.minimize,
    close: close ?? this.close,
  );

  @override
  bool operator ==(Object other) =>
      other is Look &&
      other.dark == dark &&
      other.rtl == rtl &&
      other.liquidGlass == liquidGlass &&
      other.buttons == buttons &&
      other.minimize == minimize &&
      other.close == close;

  @override
  int get hashCode =>
      Object.hash(dark, rtl, liquidGlass, buttons, minimize, close);
}

/// Switches for every [Look] option.
class LookPanel extends StatelessWidget {
  const LookPanel({super.key, required this.look, required this.onChanged});

  final Look look;
  final ValueChanged<Look> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget choice<T extends Enum>(
      String label,
      List<T> values,
      T selected,
      Look Function(T) apply,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(width: 110, child: Text(label)),
          SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [
              for (final value in values)
                ButtonSegment(value: value, label: Text(value.name)),
            ],
            selected: {selected},
            onSelectionChanged: (set) => onChanged(apply(set.first)),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Liquid Glass'),
          value: look.liquidGlass,
          onChanged: (v) => onChanged(look.copyWith(liquidGlass: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dark theme'),
          value: look.dark,
          onChanged: (v) => onChanged(look.copyWith(dark: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Right to left'),
          value: look.rtl,
          onChanged: (v) => onChanged(look.copyWith(rtl: v)),
        ),
        const SizedBox(height: 8),
        choice(
          'Buttons',
          FloatingDialogWindowButtonStyle.values,
          look.buttons,
          (v) => look.copyWith(buttons: v),
        ),
        choice(
          'Minimize',
          FloatingDialogMinimizeEffect.values,
          look.minimize,
          (v) => look.copyWith(minimize: v),
        ),
        choice(
          'Close',
          FloatingDialogCloseEffect.values,
          look.close,
          (v) => look.copyWith(close: v),
        ),
      ],
    );
  }
}
