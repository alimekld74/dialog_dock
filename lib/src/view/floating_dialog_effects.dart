// Internal: not exported from the package.
// ignore_for_file: public_member_api_docs

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../config/floating_dialog_config.dart';

/// Takes a picture of [key]'s [RepaintBoundary] and where it is on screen,
/// or `null` when it can't (not painted, not laid out).
(ui.Image, Rect)? captureFloatingWindow(
  GlobalKey key, {
  double pixelRatio = 1,
}) {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary ||
      !boundary.attached ||
      !boundary.hasSize) {
    return null;
  }
  // The layer from the last frame. Unlike `toImageSync` on the render
  // object, this also works while something inside is about to repaint
  // (a blinking cursor, an animation).
  final layer = _layerOf(boundary);
  if (layer is! OffsetLayer || !layer.attached) return null;
  try {
    final image = layer.toImageSync(
      Offset.zero & boundary.size,
      pixelRatio: pixelRatio,
    );
    final origin = boundary.localToGlobal(Offset.zero);
    return (image, origin & boundary.size);
  } catch (_) {
    return null;
  }
}

// ignore: invalid_use_of_protected_member
ContainerLayer? _layerOf(RenderObject object) => object.layer;

enum FloatingDialogEffectKind {
  minimize,
  restore,
  close,
  closeDown,
  closeToOrigin,
}

/// One running window animation, drawn from a snapshot.
class FloatingDialogEffect {
  FloatingDialogEffect({
    required this.kind,
    required this.style,
    required this.image,
    required this.windowRect,
    required this.target,
    required this.controller,
    required this.curve,
  });

  final FloatingDialogEffectKind kind;
  final FloatingDialogMinimizeEffect style;
  final ui.Image image;

  /// Where the window is (in global coordinates).
  final Rect windowRect;

  /// Where its holder item is, looked up every frame so it follows the
  /// holder bar while that animates.
  final Rect Function() target;
  final AnimationController controller;
  final Curve curve;

  /// 0 = window, 1 = fully in the holder item (or gone, for close).
  double get progress {
    final t = curve.transform(controller.value);
    return kind == FloatingDialogEffectKind.restore ? 1 - t : t;
  }
}

/// Paints running window effects above everything else in the holder.
class FloatingDialogEffectsLayer extends StatefulWidget {
  const FloatingDialogEffectsLayer({super.key});

  @override
  State<FloatingDialogEffectsLayer> createState() =>
      FloatingDialogEffectsLayerState();
}

class FloatingDialogEffectsLayerState extends State<FloatingDialogEffectsLayer>
    with TickerProviderStateMixin {
  final List<FloatingDialogEffect> _effects = [];

  /// The pictures of the effects playing now.
  @visibleForTesting
  List<ui.Image> get runningImages => [
    for (final effect in _effects) effect.image,
  ];

  /// The effects playing now.
  @visibleForTesting
  List<FloatingDialogEffectKind> get runningKinds => [
    for (final effect in _effects) effect.kind,
  ];
  final _repaint = _Repaint();

  /// Plays an effect; [onDone] runs when it ends (or is dropped).
  void play({
    required FloatingDialogEffectKind kind,
    required FloatingDialogMinimizeEffect style,
    required ui.Image image,
    required Rect windowRect,
    required Rect Function() target,
    required Duration duration,
    required bool disposeImage,
    VoidCallback? onDone,
  }) {
    if (!mounted) {
      if (disposeImage) image.dispose();
      onDone?.call();
      return;
    }
    final controller = AnimationController(vsync: this, duration: duration);
    final effect = FloatingDialogEffect(
      kind: kind,
      style: style,
      image: image,
      windowRect: windowRect,
      target: target,
      controller: controller,
      curve: switch (kind) {
        FloatingDialogEffectKind.close => Curves.easeIn,
        FloatingDialogEffectKind.closeDown => Curves.easeInCubic,
        FloatingDialogEffectKind.closeToOrigin => Curves.easeInOutCubic,
        _ => Curves.easeInOut,
      },
    );
    controller.addListener(_repaint.notify);
    setState(() => _effects.add(effect));
    controller.forward().whenCompleteOrCancel(() {
      controller.dispose();
      if (disposeImage) image.dispose();
      if (mounted) setState(() => _effects.remove(effect));
      onDone?.call();
    });
  }

  @override
  void dispose() {
    for (final effect in _effects) {
      effect.controller.stop(canceled: true);
    }
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_effects.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EffectsPainter(List.of(_effects), _repaint, context),
      ),
    );
  }
}

class _Repaint extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _EffectsPainter extends CustomPainter {
  _EffectsPainter(this.effects, Listenable repaint, this.context)
    : super(repaint: repaint);

  final List<FloatingDialogEffect> effects;
  final BuildContext context;

  @override
  void paint(Canvas canvas, Size size) {
    // Effect rects are global; this layer may not start at the origin.
    final box = context.findRenderObject();
    final origin =
        box is RenderBox && box.attached
            ? box.localToGlobal(Offset.zero)
            : Offset.zero;
    canvas.save();
    canvas.translate(-origin.dx, -origin.dy);
    for (final effect in effects) {
      final t = effect.progress.clamp(0.0, 1.0);
      switch (effect.kind) {
        case FloatingDialogEffectKind.close:
          _paintClose(canvas, effect, t);
        case FloatingDialogEffectKind.closeDown:
          _paintCloseDown(canvas, effect, t);
        case FloatingDialogEffectKind.closeToOrigin:
          _paintToOrigin(canvas, effect, t);
        case FloatingDialogEffectKind.minimize ||
            FloatingDialogEffectKind.restore:
          switch (effect.style) {
            case FloatingDialogMinimizeEffect.genie:
              _paintGenie(canvas, effect, t);
            case FloatingDialogMinimizeEffect.scale:
              _paintScale(canvas, effect, t);
            case FloatingDialogMinimizeEffect.fade:
              _paintFade(canvas, effect, t);
          }
      }
    }
    canvas.restore();
  }

  Paint _imagePaint(ui.Image image, double opacity) =>
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Color.fromRGBO(0, 0, 0, opacity);

  void _drawImage(Canvas canvas, ui.Image image, Rect dst, double opacity) {
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      dst,
      _imagePaint(image, opacity),
    );
  }

  /// macOS close: a quick fade while shrinking a little.
  void _paintClose(Canvas canvas, FloatingDialogEffect e, double t) {
    final scale = 1 - 0.08 * t;
    final rect = Rect.fromCenter(
      center: e.windowRect.center,
      width: e.windowRect.width * scale,
      height: e.windowRect.height * scale,
    );
    _drawImage(canvas, e.image, rect, 1 - t);
  }

  /// Drops towards the bottom center of the screen ([FloatingDialogEffect.
  /// target]) while shrinking and fading out.
  void _paintCloseDown(Canvas canvas, FloatingDialogEffect e, double t) {
    final rect = Rect.lerp(e.windowRect, e.target(), t)!;
    _drawImage(canvas, e.image, rect, (1 - t).clamp(0.0, 1.0));
  }

  /// Like a [Hero] flying back: shrinks into the widget it came from.
  void _paintToOrigin(Canvas canvas, FloatingDialogEffect e, double t) {
    final rect = Rect.lerp(e.windowRect, e.target(), t)!;
    _drawImage(canvas, e.image, rect, t > 0.6 ? (1 - t) / 0.4 : 1);
  }

  void _paintFade(Canvas canvas, FloatingDialogEffect e, double t) {
    final scale = 1 - 0.15 * t;
    final rect = Rect.fromCenter(
      center: e.windowRect.center,
      width: e.windowRect.width * scale,
      height: e.windowRect.height * scale,
    );
    _drawImage(canvas, e.image, rect, 1 - t);
  }

  /// macOS "Scale effect": the window shrinks straight into its item.
  void _paintScale(Canvas canvas, FloatingDialogEffect e, double t) {
    final rect = Rect.lerp(e.windowRect, e.target(), t)!;
    _drawImage(canvas, e.image, rect, t > 0.85 ? (1 - t) / 0.15 : 1);
  }

  /// macOS "Genie effect": the edge nearest the item funnels into it while
  /// the rest of the window slides in after it.
  void _paintGenie(Canvas canvas, FloatingDialogEffect e, double t) {
    final window = e.windowRect;
    final target = e.target();
    // Like the Dock: pour down into an item below the window (the holder
    // bar); sideways only for an item beside it (the pinned edge dock).
    final below = target.center.dy > window.bottom;
    final above = target.center.dy < window.top;
    final beside =
        target.center.dx > window.right || target.center.dx < window.left;
    final vertical = below || above || !beside;
    // Signed main axis: +1 when the item is down / right of the window.
    final forward =
        vertical
            ? target.center.dy >= window.center.dy
            : target.center.dx >= window.center.dx;

    // Main (m) and cross (c) coordinates; m grows towards the item.
    double m(Offset p) => (vertical ? p.dy : p.dx) * (forward ? 1 : -1);
    double c(Offset p) => vertical ? p.dx : p.dy;
    Offset point(double mm, double cc) {
      final main = mm * (forward ? 1 : -1);
      return vertical ? Offset(cc, main) : Offset(main, cc);
    }

    final m0 = math.min(m(window.topLeft), m(window.bottomRight));
    final m1 = math.max(m(window.topLeft), m(window.bottomRight));
    final c0 = c(window.topLeft);
    final c1 = c(window.bottomRight);
    final targetEnd = math.max(m(target.topLeft), m(target.bottomRight));
    final tc0 = c(target.topLeft);
    final tc1 = c(target.bottomRight);

    // First the near edge narrows (squeeze), then everything slides in.
    final squeeze = Curves.easeInOut.transform((t / 0.4).clamp(0.0, 1.0));
    final slide = Curves.easeIn.transform(((t - 0.2) / 0.8).clamp(0.0, 1.0));
    final travel = targetEnd - m0;

    const rows = 32;
    final positions = <Offset>[];
    final texture = <Offset>[];
    final w = e.image.width.toDouble();
    final h = e.image.height.toDouble();
    for (var r = 0; r <= rows; r++) {
      final v = r / rows; // 0 = far edge, 1 = edge nearest the item
      final mm = math.min(m0 + v * (m1 - m0) + slide * travel, targetEnd);
      final n = travel == 0 ? 1.0 : ((mm - m0) / travel).clamp(0.0, 1.0);
      final s = (1 - math.cos(math.pi * n)) / 2;
      final ca = c0 + (tc0 - c0) * squeeze * s;
      final cb = c1 + (tc1 - c1) * squeeze * s;
      positions
        ..add(point(mm, ca))
        ..add(point(mm, cb));
      // Texture coordinates in image pixels; v runs along the flow.
      final along = forward ? v : 1 - v;
      if (vertical) {
        texture
          ..add(Offset(0, along * h))
          ..add(Offset(w, along * h));
      } else {
        texture
          ..add(Offset(along * w, 0))
          ..add(Offset(along * w, h));
      }
    }
    final indices = <int>[];
    for (var r = 0; r < rows; r++) {
      final i = r * 2;
      indices.addAll([i, i + 1, i + 2, i + 1, i + 3, i + 2]);
    }
    final opacity = t > 0.9 ? (1 - t) / 0.1 : 1.0;
    // The paint's alpha fades the shader directly: no offscreen layer.
    final paint =
        Paint()
          ..filterQuality = FilterQuality.low
          ..shader = ui.ImageShader(
            e.image,
            TileMode.clamp,
            TileMode.clamp,
            Matrix4.identity().storage,
          )
          ..color = Color.fromRGBO(0, 0, 0, opacity);
    canvas.drawVertices(
      ui.Vertices(
        VertexMode.triangles,
        positions,
        textureCoordinates: texture,
        indices: indices,
      ),
      BlendMode.srcOver,
      paint,
    );
  }

  @override
  bool shouldRepaint(_EffectsPainter oldDelegate) =>
      oldDelegate.effects.length != effects.length ||
      !oldDelegate.effects.every(effects.contains);
}
