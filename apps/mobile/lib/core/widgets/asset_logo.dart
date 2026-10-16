import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact, offline-safe asset marks for selectors and trade rows.
class AssetLogo extends StatelessWidget {
  const AssetLogo(this.symbol, {super.key, this.size = 30});

  final String symbol;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = symbol.toUpperCase();
    final isBtc = code.startsWith('BTC');
    final isEth = code.startsWith('ETH');
    final isGold = code.startsWith('XAU');
    final isSilver = code.startsWith('XAG');
    final color = isBtc
        ? const Color(0xfff7931a)
        : isEth
        ? const Color(0xff627eea)
        : isGold
        ? const Color(0xffc79222)
        : isSilver
        ? const Color(0xff71808f)
        : AppColors.green;
    final glyph = isBtc
        ? '\u20bf'
        : isEth
        ? '\u25c7'
        : isGold
        ? 'Au'
        : isSilver
        ? 'Ag'
        : code.isEmpty
        ? '?'
        : code.substring(0, 1);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .38)),
      ),
      child: Text(
        glyph,
        style: TextStyle(
          color: color,
          fontSize: glyph.length > 1 ? size * .34 : size * .52,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
