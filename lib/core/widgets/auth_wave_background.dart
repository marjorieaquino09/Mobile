import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AuthWaveBackground extends StatelessWidget {
  const AuthWaveBackground({
    super.key,
    this.topLeft = false,
    this.bottomRight = true,
  });

  final bool topLeft;
  final bool bottomRight;

  @override
  Widget build(BuildContext context) {
    final sari = context.sari;
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _AuthWavePainter(
            topLeft: topLeft,
            bottomRight: bottomRight,
            darkColor: sari.waveDark,
            lightColor: sari.waveLight,
          ),
        ),
      ),
    );
  }
}

class _AuthWavePainter extends CustomPainter {
  const _AuthWavePainter({
    required this.topLeft,
    required this.bottomRight,
    required this.darkColor,
    required this.lightColor,
  });

  final bool topLeft;
  final bool bottomRight;
  final Color darkColor;
  final Color lightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()
      ..color = darkColor
      ..style = PaintingStyle.fill;
    final light = Paint()
      ..color = lightColor
      ..style = PaintingStyle.fill;

    if (topLeft) {
      final topLeftDark = Path()
        ..moveTo(0, size.height * 0.15)
        ..cubicTo(
          size.width * 0.10,
          size.height * 0.02,
          size.width * 0.28,
          size.height * 0.20,
          size.width * 0.42,
          size.height * 0.18,
        )
        ..cubicTo(
          size.width * 0.62,
          size.height * 0.15,
          size.width * 0.75,
          size.height * 0.02,
          size.width,
          size.height * 0.03,
        )
        ..lineTo(size.width, 0)
        ..lineTo(0, 0)
        ..close();

      final topLeftLight = Path()
        ..moveTo(0, size.height * 0.55)
        ..cubicTo(
          size.width * 0.15,
          size.height * 0.44,
          size.width * 0.35,
          size.height * 0.56,
          size.width * 0.52,
          size.height * 0.52,
        )
        ..cubicTo(
          size.width * 0.74,
          size.height * 0.48,
          size.width * 0.90,
          size.height * 0.60,
          size.width,
          size.height * 0.56,
        )
        ..lineTo(size.width, 0)
        ..lineTo(0, 0)
        ..close();

      canvas.drawPath(topLeftLight, light);
      canvas.drawPath(topLeftDark, dark);
    }

    if (bottomRight) {
      final bottomRightDark = Path()
        ..moveTo(size.width * 0.52, size.height)
        ..cubicTo(
          size.width * 0.70,
          size.height * 0.82,
          size.width * 0.86,
          size.height * 0.56,
          size.width,
          size.height * 0.32,
        )
        ..lineTo(size.width, size.height)
        ..close();

      final bottomRightLight = Path()
        ..moveTo(size.width * 0.65, size.height)
        ..cubicTo(
          size.width * 0.80,
          size.height * 0.84,
          size.width * 0.92,
          size.height * 0.66,
          size.width,
          size.height * 0.46,
        )
        ..lineTo(size.width, size.height)
        ..close();

      canvas.drawPath(bottomRightLight, light);
      canvas.drawPath(bottomRightDark, dark);
    }
  }

  @override
  bool shouldRepaint(covariant _AuthWavePainter oldDelegate) {
    return oldDelegate.topLeft != topLeft ||
        oldDelegate.bottomRight != bottomRight ||
        oldDelegate.darkColor != darkColor ||
        oldDelegate.lightColor != lightColor;
  }
}
