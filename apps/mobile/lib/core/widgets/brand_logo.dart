import 'package:flutter/material.dart';

/// Branded ANZEN TRADING logo asset used across the app surfaces.
class AnzenLogo extends StatelessWidget {
  const AnzenLogo({
    super.key,
    this.markOnly = true,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final bool markOnly;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset(
    markOnly
        ? 'assets/branding/anzen-trading-mark.png'
        : 'assets/branding/anzen-trading-logo.png',
    width: width,
    height: height,
    fit: fit,
    semanticLabel: 'Logo ANZEN TRADING',
  );
}
