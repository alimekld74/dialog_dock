// Internal: not exported from the package.
// ignore_for_file: public_member_api_docs

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controller/floating_dialog_holder_cubit.dart';
import '../host/floating_dialog_host_context.dart';
import '../models/floating_dialog_entry.dart';
import '../config/floating_dialog_config.dart';
import 'floating_dialog_effects.dart';
import 'floating_dialog_frame.dart';
import 'floating_dialog_holder_widget.dart';
import 'floating_dialog_routes.dart';
import 'floating_dialog_scope.dart';

/// One floating window: a full-screen navigator holding the window route
/// above an empty page. Kept mounted while minimized (offstage, tickers
/// paused, focus and semantics excluded) so the dialog keeps its state.
class FloatingDialogWindow extends StatefulWidget {
  const FloatingDialogWindow({super.key, required this.id});

  final String id;

  @override
  State<FloatingDialogWindow> createState() => FloatingDialogWindowState();
}

class FloatingDialogWindowState extends State<FloatingDialogWindow> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _focusNode = FocusNode(
    debugLabel: 'floating window',
    skipTraversal: true,
  );
  late final FloatingDialogHolderCubit _holder = context.floatingHolder;
  FloatingDialogHolderWidgetState? _holderState;
  late final List<Page<Object?>> _pages = [
    const FloatingDialogPlainPage(builder: _empty, requestFocus: false),
    FloatingDialogPlainPage(
      key: ValueKey(widget.id),
      builder:
          (_) => _WindowBody(
            id: widget.id,
            focusNode: _focusNode,
            onDismiss: dismiss,
            boxKey: _boxKey,
            boxHidden: _boxHidden,
            openFrom: _openFrom,
          ),
      onRouteCreated: (route) {
        _route = route;
        route.popped.then((result) {
          // `Navigator.pop(context, result)` inside the dialog.
          if (mounted) _holder.closeDialog(widget.id, result);
        });
      },
    ),
  ];

  ModalRoute<Object?>? _route;
  FocusNode? _lastFocus;

  /// The window box, for snapshots.
  final _boxKey = GlobalKey();

  /// Hides the live window while an effect draws its snapshot instead.
  final _boxHidden = ValueNotifier(false);

  /// Taken on minimize, played back on restore.
  ui.Image? _snapshot;

  /// Where the open animation starts (origin widget or holder item).
  Rect? Function()? _openFrom;

  bool _wasActive = false;
  bool _animate = true;

  FloatingDialogConfig get _config => _holder.config;

  double get _pixelRatio =>
      math.min(MediaQuery.maybeDevicePixelRatioOf(context) ?? 1, 1.5);

  static Rect? rectOf(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// True once the minimize fade finished; the window then goes offstage.
  bool _fadedOut = false;

  static Widget _empty(BuildContext context) => const SizedBox.shrink();

  @override
  void initState() {
    super.initState();
    _holderState = FloatingDialogHolderScope.stateOf(context);
    _holderState?.registerWindow(widget.id, this);
    final entry = _holder.state.entryOf(widget.id);
    _wasActive = entry?.isActive ?? false;
    // Built already minimized (e.g. rebuilt dormant window): no fade runs.
    _fadedOut = !_wasActive;
    if (_wasActive) {
      final originKey = _holder.actionOf(widget.id)?.originKey;
      final holderState = _holderState;
      if (originKey != null) {
        final start = rectOf(originKey);
        _openFrom = () => start;
      } else if ((entry?.wasHeld ?? false) && holderState != null) {
        // A dormant window rebuilt from its holder item grows out of it.
        final start = holderState.bubbleRect(widget.id);
        _openFrom = () => start;
      }
    }
  }

  @override
  void dispose() {
    _holderState?.unregisterWindow(widget.id, this);
    _focusNode.dispose();
    _boxHidden.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  /// Closing: the window drops to the bottom center (or fades out), or
  /// shrinks back into its origin widget.
  void _playClose() {
    final effects = _holderState?.effects;
    final wasActive = _wasActive;
    _wasActive = false;
    if (!wasActive ||
        _boxHidden.value ||
        !_animate ||
        effects == null ||
        _config.closeEffectDuration <= Duration.zero) {
      return;
    }
    final shot = captureFloatingWindow(_boxKey, pixelRatio: _pixelRatio);
    if (shot == null) return;
    final originKey = _holder.actionOf(widget.id)?.originKey;
    final config = _config;
    // Bottom center of the holder's area, for the slide-down close.
    final area = _holderState?.context.findRenderObject();
    final window = shot.$2;
    final bottomCenter =
        area is RenderBox && area.attached
            ? area.localToGlobal(area.size.bottomCenter(Offset.zero))
            : window.bottomCenter;
    final down = Rect.fromCenter(
      center: bottomCenter,
      width: window.width * 0.3,
      height: window.height * 0.3,
    );
    void play() {
      final origin = rectOf(originKey);
      effects.play(
        kind:
            origin != null
                ? FloatingDialogEffectKind.closeToOrigin
                : config.closeEffect == FloatingDialogCloseEffect.slideDown
                ? FloatingDialogEffectKind.closeDown
                : FloatingDialogEffectKind.close,
        style: config.minimizeEffect,
        image: shot.$1,
        windowRect: window,
        target:
            () =>
                rectOf(originKey) ??
                origin ??
                (config.closeEffect == FloatingDialogCloseEffect.slideDown
                    ? down
                    : window),
        duration:
            origin != null
                ? config.openEffectDuration
                : config.closeEffectDuration,
        disposeImage: true,
      );
    }

    // Between frames (the usual case) start right away; during a frame,
    // once it is done.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      play();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => play());
    }
  }

  bool get _effectsOn =>
      _animate &&
      _holderState?.effects != null &&
      _config.minimizeEffectDuration > Duration.zero;

  /// Minimizing: the window flies into its holder item.
  void _playMinimize() {
    if (!_effectsOn) return;
    final shot = captureFloatingWindow(_boxKey, pixelRatio: _pixelRatio);
    if (shot == null) return;
    _boxHidden.value = true;
    _snapshot?.dispose();
    _snapshot = shot.$1.clone();
    final holderState = _holderState!;
    holderState.effects!.play(
      kind: FloatingDialogEffectKind.minimize,
      style: _config.minimizeEffect,
      image: shot.$1,
      windowRect: shot.$2,
      target: () => holderState.bubbleRect(widget.id),
      duration: _config.minimizeEffectDuration,
      disposeImage: true,
    );
  }

  /// Restoring: the window flies back out of its holder item.
  void _playRestore() {
    final stored = _snapshot;
    _snapshot = null;
    if (!_effectsOn) {
      stored?.dispose();
      _boxHidden.value = false;
      return;
    }
    final holderState = _holderState!;
    // Read now: the item leaves the holder on the next frame.
    final from = holderState.bubbleRect(widget.id);
    _boxHidden.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final effects = holderState.effects;
      // The window was just painted (nearly invisible) with the current
      // theme and language. Picture that, not the snapshot taken when it
      // was minimized, which may show an old theme or language.
      final fresh =
          mounted
              ? captureFloatingWindow(_boxKey, pixelRatio: _pixelRatio)
              : null;
      final image = fresh?.$1 ?? stored;
      if (fresh != null) stored?.dispose();
      final to = fresh?.$2 ?? (mounted ? rectOf(_boxKey) : null);
      if (!mounted || effects == null || to == null || image == null) {
        image?.dispose();
        if (mounted) _boxHidden.value = false;
        return;
      }
      effects.play(
        kind: FloatingDialogEffectKind.restore,
        style: _config.minimizeEffect,
        image: image,
        windowRect: to,
        target: () => from,
        duration: _config.minimizeEffectDuration,
        disposeImage: true,
        onDone: () {
          if (mounted) _boxHidden.value = false;
        },
      );
    });
  }

  /// Back: closes a dialog opened from this window first, then dismisses
  /// the window itself.
  void handleBack() {
    final route = _route;
    if (route != null && !route.isCurrent) {
      _navigatorKey.currentState?.maybePop();
      return;
    }
    dismiss();
  }

  /// Tap outside / Esc: closes the window, or sends it back to the holder.
  void dismiss() {
    if (!_holder.dismissActive()) showFloatingDialogPauseRefused(context);
  }

  void _onActiveChanged(bool active) {
    _wasActive = active;
    if (active) {
      setState(() => _fadedOut = false);
      _playRestore();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final last = _lastFocus;
        _lastFocus = null;
        if (last != null && last.context != null && last.canRequestFocus) {
          last.requestFocus();
        } else {
          _focusNode.requestFocus();
        }
      });
    } else {
      _playMinimize();
      final primary = FocusManager.instance.primaryFocus;
      final scope = _navigatorKey.currentState?.focusNode;
      _lastFocus =
          primary != null && scope != null && primary.ancestors.contains(scope)
              ? primary
              : null;
      // The window stays mounted, so tooltips under the pointer (e.g. the
      // minimize button's) never get a mouse exit; dismiss them.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Tooltip.dismissAllToolTips(),
      );
    }
  }

  void _onFadeEnd() {
    if (!mounted) return;
    // With effects on the fade takes no time and ends during a build:
    // apply it once that frame is done.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onFadeEnd());
      return;
    }
    final active = _holder.state.entryOf(widget.id)?.isActive ?? false;
    if (_fadedOut != !active) setState(() => _fadedOut = !active);
  }

  @override
  Widget build(BuildContext context) {
    final config = _holder.config;
    _animate = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return BlocListener<FloatingDialogHolderCubit, FloatingDialogHolderState>(
      listenWhen:
          (previous, current) =>
              previous.entryOf(widget.id)?.isActive !=
              current.entryOf(widget.id)?.isActive,
      listener: (context, state) {
        final isActive = state.entryOf(widget.id)?.isActive;
        // Removed (closed): snapshot it now, while it is still on screen,
        // and play the close effect, not the minimize effect.
        if (isActive == null) {
          _playClose();
        } else {
          _onActiveChanged(isActive);
        }
      },
      child: BlocSelector<
        FloatingDialogHolderCubit,
        FloatingDialogHolderState,
        bool?
      >(
        selector: (state) => state.entryOf(widget.id)?.isActive,
        builder: (context, isActive) {
          if (isActive == null) return const SizedBox.shrink();
          final active = isActive;
          return Offstage(
            offstage: !active && _fadedOut,
            child: IgnorePointer(
              ignoring: !active,
              child: ExcludeFocus(
                excluding: !active,
                child: ExcludeSemantics(
                  excluding: !active,
                  // Tickers pause once the fade is done, so in-flight
                  // animations (e.g. a tooltip hiding) finish.
                  child: TickerMode(
                    enabled: active || !_fadedOut,
                    child: AnimatedOpacity(
                      opacity: active ? 1 : 0,
                      // The minimize / restore effects show the window
                      // themselves; the fade is for reduced motion.
                      duration:
                          _effectsOn
                              ? Duration.zero
                              : config.windowAnimationDuration,
                      curve: config.animationCurve,
                      onEnd: _onFadeEnd,
                      child: HeroControllerScope.none(
                        child: Navigator(
                          key: _navigatorKey,
                          pages: _pages,
                          onDidRemovePage: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The window route's content: barrier, sized window box, shortcuts.
class _WindowBody extends StatefulWidget {
  const _WindowBody({
    required this.id,
    required this.focusNode,
    required this.onDismiss,
    required this.boxKey,
    required this.boxHidden,
    required this.openFrom,
  });

  final String id;
  final FocusNode focusNode;
  final VoidCallback onDismiss;
  final GlobalKey boxKey;
  final ValueListenable<bool> boxHidden;

  /// Where the open animation starts; `null` zooms in from the center.
  final Rect? Function()? openFrom;

  @override
  State<_WindowBody> createState() => _WindowBodyState();
}

class _WindowBodyState extends State<_WindowBody>
    with SingleTickerProviderStateMixin {
  late final FloatingDialogHolderCubit _holder = context.floatingHolder;
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: _holder.config.openEffectDuration,
  );
  bool _openStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openStarted) return;
    _openStarted = true;
    final animate =
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) &&
        _holder.config.openEffectDuration > Duration.zero &&
        (_holder.state.entryOf(widget.id)?.isActive ?? false);
    animate ? _open.forward() : _open.value = 1;
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  /// Zooms in (macOS window open), or grows out of the origin rect.
  Widget _opening(Widget box, Size size, Size area) {
    final from = widget.openFrom?.call();
    final holderBox =
        FloatingDialogHolderScope.stateOf(context)?.context.findRenderObject();
    final origin =
        holderBox is RenderBox && holderBox.attached
            ? holderBox.localToGlobal(Offset.zero)
            : Offset.zero;
    final end = Rect.fromCenter(
      center: origin + area.center(Offset.zero),
      width: size.width,
      height: size.height,
    );
    return AnimatedBuilder(
      animation: _open,
      child: box,
      // Always the same widgets, even when finished: changing the tree shape
      // would move the keyed window box during layout, which breaks any
      // tooltip (OverlayPortal) showing inside it.
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_open.value);
        final rect =
            from != null
                ? Rect.lerp(from, end, t)!
                : Rect.fromCenter(
                  center: end.center,
                  width: end.width * (0.94 + 0.06 * t),
                  height: end.height * (0.94 + 0.06 * t),
                );
        final opacity =
            from != null ? (t / 0.3).clamp(0.0, 1.0) : t.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform(
            transform: Matrix4.translationValues(
              rect.left - end.left,
              rect.top - end.top,
              0,
            )..multiply(
              Matrix4.diagonal3Values(
                rect.width / end.width,
                rect.height / end.height,
                1,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// Built once: resizing, pinning or minimizing never rebuilds or
  /// recreates the dialog content.
  late final Widget _content = _buildContent();

  Widget _buildContent() {
    final action = _holder.actionOf(widget.id)!;
    // Resolves the latest builder whenever the content rebuilds.
    final dialog = Builder(
      builder:
          (context) => (_holder.actionOf(widget.id) ?? action).builder(context),
    );
    if (!action.showFrame) {
      return FloatingDialogScope(
        entryId: widget.id,
        holder: _holder,
        hasFrame: false,
        child: dialog,
      );
    }
    final body = FloatingDialogScope(
      entryId: widget.id,
      holder: _holder,
      hasFrame: true,
      child: Builder(
        // Existing Dialog / AlertDialog widgets blend into the window
        // instead of drawing a second card inside it.
        builder: (context) {
          final theme = Theme.of(context);
          return Theme(
            data: theme.copyWith(
              dialogTheme: theme.dialogTheme.copyWith(
                insetPadding: EdgeInsets.zero,
                elevation: 0,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
            ),
            child: dialog,
          );
        },
      ),
    );
    return FloatingDialogScope(
      entryId: widget.id,
      holder: _holder,
      hasFrame: false,
      child: BlocSelector<
        FloatingDialogHolderCubit,
        FloatingDialogHolderState,
        (String, bool, bool)
      >(
        bloc: _holder,
        selector: (state) {
          final entry = state.entryOf(widget.id);
          return (
            state.actionOf(widget.id)?.title ?? action.title,
            entry?.isLarge ?? false,
            entry?.isPinned ?? false,
          );
        },
        builder:
            (context, frame) =>
                FloatingDialogFrame(title: frame.$1, child: body),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    final config = _holder.config;
    return {
      if (config.dismissShortcut case final dismiss?) dismiss: widget.onDismiss,
      if (config.minimizeShortcut case final minimize?)
        minimize: () {
          if (!_holder.minimize(widget.id)) {
            showFloatingDialogPauseRefused(context);
          }
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    final config = _holder.config;
    final colors = context.floatingColors;
    return BlocSelector<
      FloatingDialogHolderCubit,
      FloatingDialogHolderState,
      FloatingDialogEntry?
    >(
      selector: (state) => state.entryOf(widget.id),
      builder: (context, entry) {
        final action = _holder.actionOf(widget.id);
        final sizeFactor =
            (entry?.isLarge ?? false)
                ? config.largeSize
                : action?.size ??
                    config.normalSize(
                      isMobile: context.isFloatingMobile,
                      isTablet: context.isFloatingTablet,
                    );
        return Stack(
          fit: StackFit.expand,
          children: [
            ModalBarrier(
              color: colors.barrier,
              onDismiss: widget.onDismiss,
              semanticsLabel: context.floatingStrings.close,
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final size = sizeFactor.resolve(constraints.biggest);
                final box = ValueListenableBuilder<bool>(
                  valueListenable: widget.boxHidden,
                  builder:
                      // Hidden but still painted (1/255), so the window
                      // can be pictured for the restore effect.
                      (context, hidden, child) =>
                          Opacity(opacity: hidden ? 1 / 255 : 1, child: child),
                  child: RepaintBoundary(
                    key: widget.boxKey,
                    child: AnimatedContainer(
                      width: size.width,
                      height: size.height,
                      duration: config.resizeAnimationDuration,
                      curve: config.animationCurve,
                      child: CallbackShortcuts(
                        bindings: _shortcuts(),
                        child: Focus(
                          focusNode: widget.focusNode,
                          autofocus: true,
                          child: Semantics(
                            scopesRoute: true,
                            namesRoute: true,
                            explicitChildNodes: true,
                            label: action?.title,
                            child: Material(
                              type: MaterialType.transparency,
                              child: _content,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                return Center(child: _opening(box, size, constraints.biggest));
              },
            ),
          ],
        );
      },
    );
  }
}
