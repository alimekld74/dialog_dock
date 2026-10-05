// Internal: not exported from the package.
// ignore_for_file: public_member_api_docs

import 'package:flutter/widgets.dart';

/// A transparent route without its own barrier or transitions. Hosts the
/// holder chrome, each window, and the empty page below each window.
class FloatingDialogPlainRoute extends PageRoute<Object?> {
  FloatingDialogPlainRoute({
    required this.builder,
    super.settings,
    super.requestFocus,
  });

  final WidgetBuilder builder;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  /// Pointers outside the content reach whatever is below.
  @override
  Widget buildModalBarrier() => const SizedBox.shrink();

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);
}

/// A [Page] for [FloatingDialogPlainRoute].
class FloatingDialogPlainPage extends Page<Object?> {
  const FloatingDialogPlainPage({
    required this.builder,
    this.onRouteCreated,
    this.requestFocus,
    super.key,
  });

  final WidgetBuilder builder;
  final void Function(FloatingDialogPlainRoute route)? onRouteCreated;

  /// Whether the route takes focus when added; defaults to its navigator's.
  final bool? requestFocus;

  @override
  Route<Object?> createRoute(BuildContext context) {
    final route = FloatingDialogPlainRoute(
      builder: builder,
      settings: this,
      requestFocus: requestFocus,
    );
    onRouteCreated?.call(route);
    return route;
  }
}

/// Invisible route pushed on the app's navigator while a window (or the
/// holder settings) is open, so Back / browser back / `maybePop` reach the
/// holder instead of leaving the page underneath.
class FloatingDialogBackRoute extends PopupRoute<void> {
  FloatingDialogBackRoute({required this.onBack, required this.onPopped})
    // Anonymous, like `showDialog` routes: never changes the browser URL.
    : super(requestFocus: false);

  /// Back was requested; the route stays.
  final VoidCallback onBack;

  /// The route was popped anyway (e.g. `Navigator.pop` by app code).
  final VoidCallback onPopped;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  RoutePopDisposition get popDisposition => RoutePopDisposition.doNotPop;

  @override
  void onPopInvokedWithResult(bool didPop, void result) {
    didPop ? onPopped() : onBack();
    super.onPopInvokedWithResult(didPop, result);
  }

  /// Never blocks pointers: the holder draws its own barrier.
  @override
  Widget buildModalBarrier() => const SizedBox.shrink();

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const SizedBox.shrink();
}
