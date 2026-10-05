import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/floating_dialog_config.dart';
import '../controller/floating_dialog_holder_cubit.dart';
import '../host/floating_dialog_host_delegate.dart';
import 'floating_dialog_effects.dart';
import 'floating_dialog_routes.dart';
import 'floating_dialog_window.dart';
import 'widgets/floating_dialog_edge_dock.dart';
import 'widgets/floating_dialog_holder_bar.dart';

/// Hosts floating dialogs for everything below it. Add it once, around your
/// app's navigator:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => FloatingDialogHolder(child: child!),
///   home: const HomePage(),
/// );
/// ```
///
/// Then open dialogs with `showFloatingDialog` instead of `showDialog`.
///
/// Windows live above every route, so they and their holder items survive
/// navigation. Each window has its own navigator: `Navigator.pop(context,
/// result)` inside a dialog closes its window, and dialogs opened from it
/// stay above it. While a window is open, Back (Android, browser) and Esc
/// dismiss it instead of leaving the page underneath.
///
/// [config], [host] and [availabilityChanges] are read once, when the holder
/// is created. Pass a [controller] to create and own it yourself.
class FloatingDialogHolder extends StatefulWidget {
  /// Creates a holder around [child].
  const FloatingDialogHolder({
    super.key,
    required this.child,
    this.config = const FloatingDialogConfig(),
    this.host,
    this.availabilityChanges,
    this.controller,
    this.navigatorKey,
  });

  /// The app, usually the `child` given to `MaterialApp.builder`.
  final Widget child;

  /// Sizes, colors, timings and limits. Read once, when the holder is
  /// created; give the holder a new `key` to apply a different config.
  final FloatingDialogConfig config;

  /// Storage, current user, messages and texts.
  final FloatingDialogHostDelegate? host;

  /// Notifies when permissions change; every open window's `isAvailable` is
  /// then re-checked.
  final Listenable? availabilityChanges;

  /// A controller you create and close yourself. When set, [config], [host]
  /// and [availabilityChanges] are ignored.
  final FloatingDialogHolderCubit? controller;

  /// The app's navigator, used to catch Back while a window is open. Found
  /// automatically when the holder wraps it (`MaterialApp.builder`) or sits
  /// inside it.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// The holder's controller, for `registerActions`, `closeDialog` and the
  /// like.
  static FloatingDialogHolderCubit of(BuildContext context) {
    final holder = maybeOf(context);
    if (holder == null) {
      throw FlutterError(
        'FloatingDialogHolder.of() called without a FloatingDialogHolder '
        'above the given context.\nAdd one with MaterialApp(builder: '
        '(context, child) => FloatingDialogHolder(child: child!)).',
      );
    }
    return holder;
  }

  /// The holder's controller, or `null` when there is no holder.
  static FloatingDialogHolderCubit? maybeOf(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<FloatingDialogHolderScope>()
          ?.state
          .holder;

  @override
  State<FloatingDialogHolder> createState() =>
      FloatingDialogHolderWidgetState();
}

/// Gives windows access to their holder's state (not exported).
class FloatingDialogHolderScope extends InheritedWidget {
  /// Inserted by [FloatingDialogHolder].
  const FloatingDialogHolderScope({
    super.key,
    required this.state,
    required super.child,
  });

  /// The holder's state.
  final FloatingDialogHolderWidgetState state;

  /// The nearest holder's state.
  static FloatingDialogHolderWidgetState? stateOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FloatingDialogHolderScope>()?.state;

  @override
  bool updateShouldNotify(FloatingDialogHolderScope oldWidget) =>
      state != oldWidget.state;
}

/// State of [FloatingDialogHolder] (not exported).
class FloatingDialogHolderWidgetState extends State<FloatingDialogHolder> {
  /// The controller (created here unless one was passed in).
  late final FloatingDialogHolderCubit holder =
      widget.controller ??
      FloatingDialogHolderCubit(
        host: widget.host,
        config: widget.config,
        availabilityChanges: widget.availabilityChanges,
      );

  final _appKey = GlobalKey(debugLabel: 'dialog_dock app');
  final _chromeNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'dialog_dock chrome',
  );
  late final _chromeObserver = _ChromeObserver(_scheduleBackRouteSync);
  final Map<String, FloatingDialogWindowState> _windows = {};
  final Map<Object, BuildContext> _anchors = {};
  final _effectsKey = GlobalKey<FloatingDialogEffectsLayerState>();

  /// Plays window animations above everything.
  FloatingDialogEffectsLayerState? get effects => _effectsKey.currentState;

  /// Lets [bubbleRect] find the holder item of [id].
  void registerAnchor(Object id, BuildContext context) =>
      _anchors[id] = context;

  /// Undoes [registerAnchor].
  void unregisterAnchor(Object id, BuildContext context) {
    if (_anchors[id] == context) _anchors.remove(id);
  }

  Rect? _anchorRect(Object id) {
    final box = _anchors[id]?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Where window [id]'s holder item is (global coordinates): the item
  /// itself, else the collapsed holder or dock, else the holder corner.
  Rect bubbleRect(String id) {
    final entry = holder.state.entryOf(id);
    final pinned = entry?.isPinned ?? false;
    final exact =
        _anchorRect(id) ??
        _anchorRect(
          pinned ? FloatingDialogAnchor.dock : FloatingDialogAnchor.holder,
        );
    if (exact != null) return exact;
    final config = holder.config;
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? MediaQuery.sizeOf(context);
    final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const d = 40.0;
    final atEnd = !pinned;
    final x =
        (rtl == atEnd)
            ? config.holderEndOffset
            : size.width - config.holderEndOffset - d;
    final y =
        pinned
            ? size.height / 2 - d / 2
            : size.height - config.holderBottomOffset - d;
    return origin + Offset(x, y) & const Size(d, d);
  }

  FloatingDialogBackRoute? _backRoute;
  NavigatorState? _appNavigatorCache;
  String? _activeId;
  FocusNode? _appFocus;

  static const _chromePages = [FloatingDialogPlainPage(builder: _buildChrome)];

  static Widget _buildChrome(BuildContext context) => const Stack(
    fit: StackFit.expand,
    children: [FloatingDialogEdgeDock(), FloatingDialogHolderBar()],
  );

  /// Lets the holder route Back to window [id].
  void registerWindow(String id, FloatingDialogWindowState window) =>
      _windows[id] = window;

  /// Undoes [registerWindow].
  void unregisterWindow(String id, FloatingDialogWindowState window) {
    if (_windows[id] == window) _windows.remove(id);
  }

  void _onActiveChanged(String? activeId) {
    final previous = _activeId;
    _activeId = activeId;
    if (previous == null && activeId != null) {
      _appFocus = FocusManager.instance.primaryFocus;
    } else if (previous != null && activeId == null) {
      final focus = _appFocus;
      _appFocus = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focus != null && focus.context != null && focus.canRequestFocus) {
          focus.requestFocus();
        }
      });
    }
    _syncBackRoute();
  }

  void _scheduleBackRouteSync() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncBackRoute());

  /// Keeps the Back-catching route on the app navigator exactly while a
  /// window or the holder settings are open.
  void _syncBackRoute() {
    if (!mounted) return;
    final needed =
        holder.state.activeEntry != null ||
        (_chromeNavigatorKey.currentState?.canPop() ?? false);
    if (needed == (_backRoute != null)) return;
    if (needed) {
      final navigator = _appNavigator();
      if (navigator == null) return;
      late final FloatingDialogBackRoute route;
      route = FloatingDialogBackRoute(
        onBack: _handleBack,
        onPopped: () {
          if (!identical(_backRoute, route)) return;
          _backRoute = null;
          _handleBack();
          _scheduleBackRouteSync();
        },
      );
      _backRoute = route;
      navigator.push(route);
    } else {
      final route = _backRoute!;
      _backRoute = null;
      if (route.isActive) route.navigator?.removeRoute(route);
    }
  }

  void _handleBack() {
    final chrome = _chromeNavigatorKey.currentState;
    if (chrome != null && chrome.canPop()) {
      chrome.maybePop();
      return;
    }
    final id = holder.state.activeEntry?.id;
    if (id != null) _windows[id]?.handleBack();
  }

  NavigatorState? _appNavigator() {
    final explicit = widget.navigatorKey?.currentState;
    if (explicit != null) return explicit;
    final cached = _appNavigatorCache;
    if (cached != null && cached.mounted) return cached;
    NavigatorState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        found = element.state as NavigatorState;
        return;
      }
      element.visitChildren(visit);
    }

    final app = _appKey.currentContext as Element?;
    app?.visitChildren(visit);
    return _appNavigatorCache = found ?? Navigator.maybeOf(context);
  }

  @override
  void dispose() {
    final route = _backRoute;
    _backRoute = null;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
    if (widget.controller == null) holder.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingDialogHolderScope(
      state: this,
      child: BlocProvider.value(
        value: holder,
        child: BlocListener<
          FloatingDialogHolderCubit,
          FloatingDialogHolderState
        >(
          listenWhen:
              (previous, current) =>
                  previous.activeEntry?.id != current.activeEntry?.id,
          listener: (context, state) => _onActiveChanged(state.activeEntry?.id),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ExcludeWhileActive(
                child: KeyedSubtree(key: _appKey, child: widget.child),
              ),
              Positioned.fill(
                child: _ExcludeWhileActive(
                  child: HeroControllerScope.none(
                    child: Navigator(
                      key: _chromeNavigatorKey,
                      // Never takes focus on its own (e.g. at startup); its
                      // settings dialog asks for it explicitly.
                      requestFocus: false,
                      pages: _chromePages,
                      onDidRemovePage: (_) {},
                      observers: [_chromeObserver],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: BlocSelector<
                  FloatingDialogHolderCubit,
                  FloatingDialogHolderState,
                  List<String>
                >(
                  selector: (state) => state.mountedIds,
                  builder:
                      (context, ids) => Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final id in ids)
                            if (holder.actionOf(id) != null)
                              FloatingDialogWindow(key: ValueKey(id), id: id),
                        ],
                      ),
                ),
              ),
              Positioned.fill(
                child: FloatingDialogEffectsLayer(key: _effectsKey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keyboard focus and screen readers can't reach the app or the holder bar
/// while a window is open.
class _ExcludeWhileActive extends StatelessWidget {
  const _ExcludeWhileActive({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<FloatingDialogHolderCubit, FloatingDialogHolderState, bool>(
        selector: (state) => state.activeEntry != null,
        builder:
            (context, active) => ExcludeSemantics(
              excluding: active,
              child: ExcludeFocus(excluding: active, child: child),
            ),
      );
}

class _ChromeObserver extends NavigatorObserver {
  _ChromeObserver(this.onChanged);

  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();
}

/// Marks a holder item (or the collapsed holder / dock) so window
/// animations can fly to it.
class FloatingDialogAnchor extends StatefulWidget {
  /// Marks [child] as the holder item for [id].
  const FloatingDialogAnchor({
    super.key,
    required this.id,
    required this.child,
  });

  /// Id of the collapsed holder bar.
  static const holder = #floatingDialogHolder;

  /// Id of the collapsed pinned dock.
  static const dock = #floatingDialogDock;

  /// A window id, or [holder] / [dock].
  final Object id;

  /// The item.
  final Widget child;

  @override
  State<FloatingDialogAnchor> createState() => _FloatingDialogAnchorState();
}

class _FloatingDialogAnchorState extends State<FloatingDialogAnchor> {
  FloatingDialogHolderWidgetState? _holder;

  @override
  void initState() {
    super.initState();
    _holder = FloatingDialogHolderScope.stateOf(context);
    _holder?.registerAnchor(widget.id, context);
  }

  @override
  void didUpdateWidget(FloatingDialogAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _holder?.unregisterAnchor(oldWidget.id, context);
      _holder?.registerAnchor(widget.id, context);
    }
  }

  @override
  void dispose() {
    _holder?.unregisterAnchor(widget.id, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
