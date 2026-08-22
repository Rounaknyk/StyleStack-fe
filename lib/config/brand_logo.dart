import 'package:flutter/material.dart';

/// The transparent StyleStack mark for normal in-app placements. The opaque
/// splash asset is deliberately reserved for the full-green startup screen.
class StyleStackLogo extends StatelessWidget {
  const StyleStackLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/stylestack_s_logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}
