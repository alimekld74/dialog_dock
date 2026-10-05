import 'package:dialog_dock/dialog_dock.dart';
import 'package:flutter/material.dart';

/// `originKey`: the window grows out of the tapped tile and shrinks back
/// into it on close, like a Hero.
class GalleryDemo extends StatefulWidget {
  const GalleryDemo({super.key});

  @override
  State<GalleryDemo> createState() => _GalleryDemoState();
}

class _GalleryDemoState extends State<GalleryDemo> {
  static const _art = [
    ('Sunrise', [Color(0xFFFF9A8B), Color(0xFFFF6A88), Color(0xFFFF99AC)]),
    ('Lagoon', [Color(0xFF13547A), Color(0xFF80D0C7)]),
    ('Meadow', [Color(0xFF96E6A1), Color(0xFFD4FC79)]),
    ('Dusk', [Color(0xFF30CFD0), Color(0xFF330867)]),
  ];

  final _keys = [for (final _ in _art) GlobalKey()];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < _art.length; i++)
          GestureDetector(
            onTap: () => _open(i),
            child: _Art(
              key: _keys[i], // the GlobalKey passed as originKey
              colors: _art[i].$2,
              width: 120,
              height: 90,
            ),
          ),
      ],
    );
  }

  void _open(int i) {
    final (title, colors) = _art[i];
    showFloatingDialog<void>(
      context: context,
      id: 'art-$i',
      title: title,
      icon: Icons.image_outlined,
      originKey: _keys[i],
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _Art(colors: colors),
          ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({super.key, required this.colors, this.width, this.height});

  final List<Color> colors;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}
