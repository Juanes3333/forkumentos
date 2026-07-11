import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Theme-aware Forkumentos mark (light SVG on dark theme, dark SVG on light).
final class ForkumentosLogo extends StatelessWidget {
  const ForkumentosLogo({super.key, this.height = 48});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = isDark
        ? 'assets/logo/forkumentosLight.svg'
        : 'assets/logo/forkumentosDark.svg';

    return SvgPicture.asset(asset, height: height);
  }
}
