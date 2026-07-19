import 'package:flutter/material.dart';

import 'design_system.dart';

/// The StyleStack mark, kept as a vector so it stays crisp at every size.
/// It intentionally has no background; callers can place it on a tile, splash,
/// app bar, or avatar surface as needed.
class StyleStackLogo extends StatelessWidget {
  const StyleStackLogo({super.key, this.size = 48, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _StyleStackLogoPainter(color ?? DesignSystem.primary),
  );
}

class _StyleStackLogoPainter extends CustomPainter {
  const _StyleStackLogoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final center = w / 2;

    // Jacket shoulders and lapels.
    final left = Path()
      ..moveTo(center - w * .08, h * .18)
      ..lineTo(center - w * .38, h * .34)
      ..lineTo(center - w * .25, h * .47)
      ..lineTo(center - w * .13, h * .83)
      ..lineTo(center - w * .02, h * .83)
      ..lineTo(center - w * .02, h * .42)
      ..close();
    final right = Path()
      ..moveTo(center + w * .08, h * .18)
      ..lineTo(center + w * .38, h * .34)
      ..lineTo(center + w * .25, h * .47)
      ..lineTo(center + w * .13, h * .83)
      ..lineTo(center + w * .02, h * .83)
      ..lineTo(center + w * .02, h * .42)
      ..close();
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);

    // Shirt, collar and tie.
    final shirt = Paint()..color = Colors.white;
    canvas.drawPath(
      Path()
        ..moveTo(center - w * .12, h * .22)
        ..lineTo(center, h * .42)
        ..lineTo(center + w * .12, h * .22)
        ..lineTo(center + w * .07, h * .16)
        ..lineTo(center - w * .07, h * .16)
        ..close(),
      shirt,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center, h * .40)
        ..lineTo(center + w * .045, h * .72)
        ..lineTo(center, h * .78)
        ..lineTo(center - w * .045, h * .72)
        ..close(),
      paint,
    );
    canvas.drawCircle(Offset(center, h * .39), w * .035, paint);

    // Lower block motif from the supplied mark.
    canvas.drawRect(Rect.fromLTWH(w * .16, h * .84, w * .68, h * .07), paint);
    canvas.drawRect(Rect.fromLTWH(w * .16, h * .92, w * .16, h * .06), paint);
    canvas.drawRect(Rect.fromLTWH(w * .68, h * .92, w * .16, h * .06), paint);
  }

  @override
  bool shouldRepaint(_StyleStackLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
