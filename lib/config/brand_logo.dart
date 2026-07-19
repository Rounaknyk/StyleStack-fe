import 'package:flutter/material.dart';

/// The official StyleStack mark. Keep this widget as the single branding entry
/// point so every screen uses the supplied asset consistently.
class StyleStackLogo extends StatelessWidget {
  const StyleStackLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/stylestack_logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}
