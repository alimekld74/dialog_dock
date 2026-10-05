// Internal: not exported from the package.
// ignore_for_file: public_member_api_docs

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../controller/floating_dialog_holder_cubit.dart';
import '../../host/floating_dialog_host_context.dart';
import '../floating_dialog_holder_widget.dart';
import '../floating_dialog_scope.dart';
import 'floating_dialog_holder_item.dart';
import 'floating_dialog_settings_dialog.dart';

/// Vertical holder of minimized, unpinned windows in the bottom-end corner
/// (bottom-start on phones), expanding upward and scrolling past
/// `holderMaxHeightFactor`. Hidden when empty or while a maximized window is
/// active.
class FloatingDialogHolderBar extends StatelessWidget {
  const FloatingDialogHolderBar({super.key});

  static const _entriesEquality = ListEquality<Object?>();

  @override
  Widget build(BuildContext context) {
    final config = context.floatingConfig;
    final maxHeight =
        MediaQuery.sizeOf(context).height * config.holderMaxHeightFactor;
    final isMobile = context.isFloatingMobile;
    return PositionedDirectional(
      bottom: config.holderBottomOffset,
      start: isMobile ? config.holderEndOffset : null,
      end: isMobile ? null : config.holderEndOffset,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child:
              BlocBuilder<FloatingDialogHolderCubit, FloatingDialogHolderState>(
                buildWhen:
                    (previous, current) =>
                        previous.isExpanded != current.isExpanded ||
                        previous.isLargeWindowActive !=
                            current.isLargeWindowActive ||
                        !identical(previous.actions, current.actions) ||
                        !_entriesEquality.equals(
                          previous.heldEntries,
                          current.heldEntries,
                        ),
                builder: (context, state) {
                  final hidden =
                      state.heldEntries.isEmpty || state.isLargeWindowActive;
                  return AnimatedSwitcher(
                    duration: config.holderAnimationDuration,
                    transitionBuilder:
                        (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          ),
                        ),
                    child:
                        hidden
                            ? const SizedBox.shrink()
                            : FloatingDialogGlassSurface(
                              child: AnimatedSize(
                                duration: config.holderAnimationDuration,
                                curve: config.animationCurve,
                                alignment: Alignment.bottomCenter,
                                child: _HolderItems(state: state),
                              ),
                            ),
                  );
                },
              ),
        ),
      ),
    );
  }
}

class _HolderItems extends StatelessWidget {
  const _HolderItems({required this.state});

  final FloatingDialogHolderState state;

  @override
  Widget build(BuildContext context) {
    final strings = context.floatingStrings;
    final config = context.floatingConfig;
    final holder = context.floatingHolder;
    final held = state.heldEntries;

    if (!state.isExpanded) {
      return FloatingDialogAnchor(
        id: FloatingDialogAnchor.holder,
        child: FloatingDialogCircle(
          icon:
              (color, size) =>
                  Icon(Icons.layers_outlined, color: color, size: size),
          label: strings.expandHolder,
          badgeCount: held.length,
          onTap: holder.toggleExpanded,
        ),
      );
    }

    return SingleChildScrollView(
      reverse: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: config.holderItemSpacing,
        children: [
          for (final entry in held)
            FloatingDialogAnchor(
              key: ValueKey(entry.id),
              id: entry.id,
              child: FloatingDialogCircle(
                icon:
                    (color, size) => FloatingDialogActionIcon(
                      action:
                          holder.actionOf(entry.id) ?? state.actionOf(entry.id),
                      color: color,
                      size: size,
                    ),
                dimmed: entry.isDormant,
                label: state.actionOf(entry.id)?.title ?? '',
                hint: [
                  if (entry.isDormant) strings.dormantHint,
                  strings.pinHint,
                ].join('\n'),
                longPressHint: strings.pin,
                onTap: () => restoreFloatingDialog(context, entry.id),
                onLongPress: () => holder.togglePin(entry.id),
              ),
            ),
          FloatingDialogCircle(
            icon:
                (color, size) =>
                    Icon(Icons.settings_outlined, color: color, size: size),
            label: strings.settingsTitle,
            onTap: () => showFloatingDialogSettings(context),
          ),
          IconButton(
            tooltip: strings.collapseHolder,
            onPressed: holder.toggleExpanded,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }
}
