import 'package:flutter/material.dart';

/// The official StyleStack mark. Keep this widget as the single branding entry
/// point so every screen uses the supplied asset consistently.
class StyleStackLogo extends StatelessWidget {
  const StyleStackLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.24),
    child: Image.asset(
      'assets/images/stylestack_s_logo.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    ),
  );
}
