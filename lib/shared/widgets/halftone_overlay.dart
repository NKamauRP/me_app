import 'package:flutter/material.dart';

class HalftoneOverlay extends StatelessWidget {
  const HalftoneOverlay({
    super.key,
    required this.child,
    this.opacity = 0.04,
    this.dotSize = 3.0,
    this.spacing = 10.0,
  });

  final Widget child;
  final double opacity;
  final double dotSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: CustomPaint(
                painter: _HalftonePainter(
                  dotSize: dotSize,
                  spacing: spacing,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HalftonePainter extends CustomPainter {
  _HalftonePainter({required this.dotSize, required this.spacing});

  final double dotSize;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Shift rows occasionally for a more "printed" look
        final xOffset = (y / spacing).floor() % 2 == 0 ? 0.0 : spacing / 2;
        canvas.drawCircle(Offset(x + xOffset, y), dotSize / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
