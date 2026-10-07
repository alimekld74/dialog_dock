// Internal: not exported from the package.
// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../controller/floating_dialog_holder_cubit.dart';
import '../../host/floating_dialog_host_context.dart';
import '../../models/floating_dialog_entry.dart';
import '../floating_dialog_holder_widget.dart';
import '../floating_dialog_scope.dart';
import 'floating_dialog_holder_item.dart';

/// Pinned, minimized windows on the screen's end edge.
///
/// A thin indicator, revealed on hover or tap (always expanded with
/// [FloatingDialogConfig.dockAlwaysExpanded]). Collapsing is delayed and
/// pressing inside keeps it open,
/// because on iPadOS a click arrives as a touch and the hover exits on
/// press. Scrolls when the items don't fit, and stays above the holder bar.
class FloatingDialogEdgeDock extends StatefulWidget {
  const FloatingDialogEdgeDock({super.key});

  @override
  State<FloatingDialogEdgeDock> createState() => _FloatingDialogEdgeDockState();
}

class _FloatingDialogEdgeDockState extends State<FloatingDialogEdgeDock> {
  static const _entriesEquality = ListEquality<Object?>();

  bool _revealed = false;
  Timer? _collapseTimer;

  void _reveal() {
    _collapseTimer?.cancel();
    if (!_revealed) setState(() => _revealed = true);
  }

  /// Tap on the collapsed indicator (runs after pointer-up, so it must
  /// schedule the collapse itself).
  void _revealBriefly() {
    _reveal();
    _collapseAfter(context.floatingConfig.dockTouchRevealDuration);
  }

  void _collapseAfter(Duration delay) {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(delay, () {
      if (mounted) setState(() => _revealed = false);
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchor = FloatingDialogHolderScope.stateOf(context)?.holderBarAnchor;
    if (anchor == null) return _build(context, holderMoved: false);
    return ValueListenableBuilder<Offset?>(
      valueListenable: anchor,
      builder:
          (context, point, _) => _build(context, holderMoved: point != null),
    );
  }

  Widget _build(BuildContext context, {required bool holderMoved}) {
    final config = context.floatingConfig;
    return BlocBuilder<FloatingDialogHolderCubit, FloatingDialogHolderState>(
      buildWhen:
          (previous, current) =>
              previous.isLargeWindowActive != current.isLargeWindowActive ||
              previous.heldEntries.isEmpty != current.heldEntries.isEmpty ||
              !identical(previous.actions, current.actions) ||
              !_entriesEquality.equals(
                previous.pinnedEntries,
                current.pinnedEntries,
              ),
      builder: (context, state) {
        final pinned = state.pinnedEntries;
        final hidden = pinned.isEmpty || state.isLargeWindowActive;
        final revealed = config.dockAlwaysExpanded || _revealed;
        final size = MediaQuery.sizeOf(context);
        // The holder bar shares the end edge except on phones, or once the
        // user moved it.
        final reserved =
            context.isFloatingMobile || holderMoved || state.heldEntries.isEmpty
                ? 0.0
                : config.holderBottomOffset +
                    size.height * config.holderMaxHeightFactor;
        return PositionedDirectional(
          top: 0,
          bottom: reserved,
          end: config.dockEdgeOffset,
          child: SafeArea(
            child: Center(
              child: Listener(
                onPointerDown: (_) => _reveal(),
                onPointerUp:
                    (_) => _collapseAfter(config.dockTouchRevealDuration),
                child: MouseRegion(
                  onEnter: (_) => _reveal(),
                  onExit: (_) => _collapseAfter(config.dockHoverCollapseDelay),
                  child: AnimatedSwitcher(
                    duration: config.holderAnimationDuration,
                    child:
                        hidden
                            ? const SizedBox.shrink()
                            : revealed
                            ? FloatingDialogGlassSurface(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: config.holderItemSpacing,
                                  children: [
                                    for (final entry in pinned)
                                      _DockItem(entry, key: ValueKey(entry.id)),
                                  ],
                                ),
                              ),
                            )
                            : FloatingDialogAnchor(
                              id: FloatingDialogAnchor.dock,
                              child: _DockIndicator(
                                onTap: _revealBriefly,
                                width:
                                    context.isFloatingMobile ||
                                            context.isFloatingTablet
                                        ? config.dockTouchStripWidth
                                        : config.dockHoverStripWidth,
                              ),
                            ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DockIndicator extends StatelessWidget {
  const _DockIndicator({required this.onTap, required this.width});

  final VoidCallback onTap;

  /// Tap/hover area; the visible bar stays thin.
  final double width;

  @override
  Widget build(BuildContext context) {
    final config = context.floatingConfig;
    return Semantics(
      button: true,
      label: context.floatingStrings.expandHolder,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: config.dockIndicatorHeight,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.floatingColors.dockIndicator,
                borderRadius: BorderRadius.circular(config.dockIndicatorWidth),
              ),
              child: SizedBox(
                width: config.dockIndicatorWidth,
                height: config.dockIndicatorHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem(this.entry, {super.key});

  final FloatingDialogEntry entry;

  @override
  Widget build(BuildContext context) {
    final holder = context.floatingHolder;
    final config = context.floatingConfig;
    final strings = context.floatingStrings;
    final action = holder.actionOf(entry.id) ?? holder.state.actionOf(entry.id);
    final closeColor = context.floatingColors.dockClose!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingDialogAnchor(
          id: entry.id,
          child: FloatingDialogCircle(
            icon:
                (color, size) => FloatingDialogActionIcon(
                  action: action,
                  color: color,
                  size: size,
                ),
            dimmed: entry.isDormant,
            label: action?.title ?? '',
            hint: entry.isDormant ? strings.dormantHint : null,
            onTap: () => restoreFloatingDialog(context, entry.id),
          ),
        ),
        Tooltip(
          message: strings.close,
          child: Semantics(
            button: true,
            child: InkResponse(
              onTap: () => holder.closeDialog(entry.id),
              radius: config.dockCloseTapTarget / 2,
              child: SizedBox.square(
                dimension: config.dockCloseTapTarget,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: closeColor),
                    ),
                    child: SizedBox.square(
                      dimension: config.dockCloseSize,
                      child: Icon(
                        Icons.close,
                        size: config.dockCloseIconSize,
                        color: closeColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
