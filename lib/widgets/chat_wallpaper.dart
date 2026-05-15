import 'package:flutter/material.dart';

import '../theme/wa_colors.dart';

/// Chat mesaj alanı için hafif dekoratif arka plan.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            WAColors.chatPanelBg,
            Color(0xFFE8E2D9),
            WAColors.chatPanelBg,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _ChatWallpaperPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ChatWallpaperPainter extends CustomPainter {
  static const List<_WallpaperShape> _shapes = [
    _WallpaperShape(0.08, 0.12, 28, 0.06),
    _WallpaperShape(0.22, 0.28, 18, 0.05),
    _WallpaperShape(0.38, 0.08, 22, 0.055),
    _WallpaperShape(0.52, 0.22, 14, 0.045),
    _WallpaperShape(0.68, 0.14, 32, 0.05),
    _WallpaperShape(0.84, 0.26, 20, 0.055),
    _WallpaperShape(0.14, 0.52, 24, 0.05),
    _WallpaperShape(0.32, 0.62, 16, 0.04),
    _WallpaperShape(0.48, 0.48, 26, 0.055),
    _WallpaperShape(0.62, 0.58, 12, 0.045),
    _WallpaperShape(0.78, 0.44, 30, 0.05),
    _WallpaperShape(0.92, 0.56, 18, 0.05),
    _WallpaperShape(0.06, 0.78, 20, 0.055),
    _WallpaperShape(0.26, 0.86, 14, 0.04),
    _WallpaperShape(0.44, 0.72, 28, 0.05),
    _WallpaperShape(0.58, 0.84, 16, 0.045),
    _WallpaperShape(0.74, 0.76, 22, 0.055),
    _WallpaperShape(0.88, 0.88, 12, 0.04),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final accentPaint = Paint()
      ..color = WAColors.accent.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    final ringPaint = Paint()
      ..color = WAColors.accentDark.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final shape in _shapes) {
      final center = Offset(
        size.width * shape.x,
        size.height * shape.y,
      );
      final radius = shape.radius * (size.width / 390).clamp(0.85, 1.15);
      canvas.drawCircle(center, radius, accentPaint);
      canvas.drawCircle(center, radius + 6, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WallpaperShape {
  final double x;
  final double y;
  final double radius;
  final double opacity;

  const _WallpaperShape(this.x, this.y, this.radius, this.opacity);
}
