import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../controller/floating_dialog_holder_cubit.dart';
import '../../host/floating_dialog_host_context.dart';

/// Opens the holder settings (lifetime of minimized windows). The holder bar
/// has a button for it; call this to open it from your own settings page.
Future<void> showFloatingDialogSettings(BuildContext context) {
  final holder = context.read<FloatingDialogHolderCubit>();
  return showDialog(
    context: context,
    // The nearest navigator: the holder's own one when called from the bar.
    useRootNavigator: false,
    requestFocus: true,
    builder:
        (_) => BlocProvider.value(
          value: holder,
          child: const FloatingDialogSettingsDialog(),
        ),
  );
}

/// A lifetime as a short label, e.g. "15 min" or "2 h".
String floatingDialogLifetimeLabel(BuildContext context, Duration lifetime) {
  final strings = context.floatingStrings;
  final minutes = lifetime.inMinutes;
  if (minutes % Duration.minutesPerHour == 0) {
    return strings.hoursCount(minutes ~/ Duration.minutesPerHour);
  }
  return strings.minutesCount(minutes);
}

/// Lifetime of minimized (unpinned) windows: presets or a custom minute
/// count.
class FloatingDialogSettingsDialog extends StatefulWidget {
  /// Creates the settings dialog; needs the holder above it.
  const FloatingDialogSettingsDialog({super.key});

  @override
  State<FloatingDialogSettingsDialog> createState() =>
      _FloatingDialogSettingsDialogState();
}

class _FloatingDialogSettingsDialogState
    extends State<FloatingDialogSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customController;
  late bool _customSelected;

  @override
  void initState() {
    super.initState();
    final lifetime = context.read<FloatingDialogHolderCubit>().state.lifetime;
    _customSelected =
        !context.floatingConfig.lifetimePresets.contains(lifetime);
    _customController = TextEditingController(
      text: _customSelected ? '${lifetime.inMinutes}' : '',
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String? _validateMinutes(String? value) {
    final minutes = int.tryParse(value?.trim() ?? '');
    if (minutes == null ||
        minutes < context.floatingConfig.customLifetimeMinMinutes ||
        minutes > context.floatingConfig.customLifetimeMaxMinutes) {
      return context.floatingStrings.invalidMinutes(
        context.floatingConfig.customLifetimeMinMinutes,
        context.floatingConfig.customLifetimeMaxMinutes,
      );
    }
    return null;
  }

  void _applyCustom() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final minutes = int.parse(_customController.text.trim());
    context.read<FloatingDialogHolderCubit>().setLifetime(
      Duration(minutes: minutes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.floatingStrings;
    final lifetime = context.select(
      (FloatingDialogHolderCubit cubit) => cubit.state.lifetime,
    );
    final holder = context.read<FloatingDialogHolderCubit>();

    return context.floatingHost.frameBuilder(
      context,
      title: strings.settingsTitle,
      width:
          context.isFloatingMobile
              ? MediaQuery.sizeOf(context).width *
                  context.floatingConfig.settingsMobileWidthFactor
              : context.floatingConfig.settingsDialogWidth,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: context.floatingConfig.settingsSpacing,
          children: [
            const SizedBox.shrink(),
            Text(
              strings.lifetime,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: context.floatingConfig.holderItemSpacing,
              runSpacing: context.floatingConfig.holderItemSpacing,
              children: [
                for (final preset in context.floatingConfig.lifetimePresets)
                  ChoiceChip(
                    label: Text(floatingDialogLifetimeLabel(context, preset)),
                    selected: !_customSelected && lifetime == preset,
                    onSelected: (_) {
                      setState(() => _customSelected = false);
                      holder.setLifetime(preset);
                    },
                  ),
                ChoiceChip(
                  label: Text(strings.custom),
                  selected: _customSelected,
                  onSelected:
                      (_) => setState(() {
                        _customSelected = true;
                        _customController.text = '${lifetime.inMinutes}';
                      }),
                ),
              ],
            ),
            if (_customSelected)
              TextFormField(
                controller: _customController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateMinutes,
                onFieldSubmitted: (_) => _applyCustom(),
                decoration: InputDecoration(
                  labelText: strings.customMinutes,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _applyCustom,
                  ),
                ),
              ),
            Text(
              strings.lifetimeHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
