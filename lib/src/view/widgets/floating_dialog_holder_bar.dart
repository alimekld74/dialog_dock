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
///
/// With `holderDraggable`, users drag it anywhere; the spot lives in
/// [FloatingDialogHolderWidgetState.holderBarAnchor] (memory only).
class FloatingDialogHolderBar extends StatefulWidget {
  const FloatingDialogHolderBar({super.key});

  @override
  State<FloatingDialogHolderBar> createState() =>
      _FloatingDialogHolderBarState();
}

class _FloatingDialogHolderBarState extends State<FloatingDialogHolderBar> {
  static const _entriesEquality = ListEquality<Object?>();

  final _areaKey = GlobalKey();
  final _surfaceKey = GlobalKey();

  /// The bar's bottom-center while dragging, in area coordinates.
  Offset? _dragPoint;

  ValueNotifier<Offset?>? get _anchor =>
      FloatingDialogHolderScope.stateOf(context)?.holderBarAnchor;

  RenderBox? _box(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  void _onPanStart(DragStartDetails details) {
    final area = _box(_areaKey);
    final surface = _box(_surfaceKey);
    if (area == null || surface == null) return;
    final bottomCenter = surface.localToGlobal(
      surface.size.bottomCenter(Offset.zero),
    );
    setState(() => _dragPoint = area.globalToLocal(bottomCenter));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final area = _box(_areaKey);
    final point = _dragPoint;
    if (area == null || point == null) return;
    final size = area.size;
    final next = point + details.delta;
    _dragPoint = Offset(
      next.dx.clamp(0, size.width),
      next.dy.clamp(0, size.height),
    );
    _anchor?.value = Offset(
      _dragPoint!.dx / size.width,
      _dragPoint!.dy / size.height,
    );
  }

  void _onPanEnd([DragEndDetails? _]) => setState(() => _dragPoint = null);

  @override
  Widget build(BuildContext context) {
    final config = context.floatingConfig;
    final anchor = _anchor;
    Widget layout(Offset? point, Widget? child) => CustomSingleChildLayout(
      delegate: _HolderBarLayout(
        anchor: point,
        padding: MediaQuery.paddingOf(context),
        textDirection: Directionality.of(context),
        atStart: context.isFloatingMobile,
        bottomOffset: config.holderBottomOffset,
        sideOffset: config.holderEndOffset,
        maxHeightFactor: config.holderMaxHeightFactor,
      ),
      child: child,
    );
    final bar =
        BlocBuilder<FloatingDialogHolderCubit, FloatingDialogHolderState>(
          buildWhen:
              (previous, current) =>
                  previous.isExpanded != current.isExpanded ||
                  previous.isLargeWindowActive != current.isLargeWindowActive ||
                  !identical(previous.actions, current.actions) ||
                  !_entriesEquality.equals(
                    previous.heldEntries,
                    current.heldEntries,
                  ),
          builder: (context, state) {
            final hidden =
                state.heldEntries.isEmpty || state.isLargeWindowActive;
            final draggable = config.holderDraggable && anchor != null;
            Widget surface = FloatingDialogGlassSurface(
              key: _surfaceKey,
              child: AnimatedSize(
                duration: config.holderAnimationDuration,
                curve: config.animationCurve,
                alignment: Alignment.bottomCenter,
                child: _HolderItems(state: state, draggable: draggable),
              ),
            );
            if (draggable) {
              surface = GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onPanCancel: _onPanEnd,
                child: MouseRegion(
                  cursor:
                      _dragPoint != null
                          ? SystemMouseCursors.grabbing
                          : MouseCursor.defer,
                  child: AnimatedScale(
                    scale: _dragPoint != null ? 1.06 : 1,
                    duration: const Duration(milliseconds: 120),
                    child: surface,
                  ),
                ),
              );
            }
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
              child: hidden ? const SizedBox.shrink() : surface,
            );
          },
        );
    return Positioned.fill(
      key: _areaKey,
      child:
          anchor == null
              ? layout(null, bar)
              : ValueListenableBuilder<Offset?>(
                valueListenable: anchor,
                builder: (context, point, child) => layout(point, child),
                child: bar,
              ),
    );
  }
}

/// Places the holder bar: in its corner, or with its bottom-center at the
/// dragged [anchor] (a fraction of the area), always fully on screen.
class _HolderBarLayout extends SingleChildLayoutDelegate {
  _HolderBarLayout({
    required this.anchor,
    required this.padding,
    required this.textDirection,
    required this.atStart,
    required this.bottomOffset,
    required this.sideOffset,
    required this.maxHeightFactor,
  });

  final Offset? anchor;
  final EdgeInsets padding;
  final TextDirection textDirection;
  final bool atStart;
  final double bottomOffset;
  final double sideOffset;
  final double maxHeightFactor;

  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: constraints.maxWidth,
        maxHeight: constraints.maxHeight * maxHeightFactor,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final point = anchor;
    if (point == null) {
      final left =
          (textDirection == TextDirection.rtl) != atStart
              ? sideOffset + padding.left
              : size.width - childSize.width - sideOffset - padding.right;
      final top =
          size.height - childSize.height - bottomOffset - padding.bottom;
      return Offset(left, top);
    }
    final minX = padding.left + _margin;
    final maxX = size.width - padding.right - _margin - childSize.width;
    final minY = padding.top + _margin;
    final maxY = size.height - padding.bottom - _margin - childSize.height;
    final x = point.dx * size.width - childSize.width / 2;
    final y = point.dy * size.height - childSize.height;
    return Offset(
      maxX < minX ? minX : x.clamp(minX, maxX),
      maxY < minY ? minY : y.clamp(minY, maxY),
    );
  }

  @override
  bool shouldRelayout(_HolderBarLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      padding != oldDelegate.padding ||
      textDirection != oldDelegate.textDirection ||
      atStart != oldDelegate.atStart ||
      bottomOffset != oldDelegate.bottomOffset ||
      sideOffset != oldDelegate.sideOffset ||
      maxHeightFactor != oldDelegate.maxHeightFactor;
}

class _HolderItems extends StatelessWidget {
  const _HolderItems({required this.state, required this.draggable});

  final FloatingDialogHolderState state;

  /// Shows a grip on the expanded bar.
  final bool draggable;

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

    final items = SingleChildScrollView(
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
    if (!draggable) return items;
    // A grip on top: always draggable, even when the items scroll.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(
              color: context.floatingColors.dockIndicator,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Flexible(child: items),
      ],
    );
  }
}
