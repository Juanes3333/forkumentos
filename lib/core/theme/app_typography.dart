import 'package:flutter/material.dart';

final class AppTypography {
  static const String _uiFontFamily = 'Segoe UI';
  static const String _monoFontFamily = 'Cascadia Mono';

  static const List<String> _uiFallback = <String>[
    'Segoe UI Variable',
    'Roboto',
    'Arial',
    'sans-serif',
  ];
  static const List<String> _monoFallback = <String>[
    'Consolas',
    'Roboto Mono',
    'monospace',
  ];

  static TextTheme get dense => TextTheme(
    displaySmall: _uiStyle(28, FontWeight.w600),
    headlineSmall: _uiStyle(22, FontWeight.w600),
    titleLarge: _uiStyle(18, FontWeight.w600),
    titleMedium: _uiStyle(15, FontWeight.w600),
    titleSmall: _uiStyle(13, FontWeight.w600),
    bodyLarge: _uiStyle(14, FontWeight.w400),
    bodyMedium: _uiStyle(13, FontWeight.w400),
    bodySmall: _uiStyle(12, FontWeight.w400),
    labelLarge: _uiStyle(13, FontWeight.w600),
    labelMedium: _uiStyle(12, FontWeight.w600),
    labelSmall: _uiStyle(11, FontWeight.w600),
  );

  // Colors come from ThemeData.textTheme via AppTheme.apply.
  static TextStyle get monospace => const TextStyle(
    fontFamily: _monoFontFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: 12,
    height: 1.35,
  );

  static TextStyle _uiStyle(double size, FontWeight weight) {
    return TextStyle(
      fontFamily: _uiFontFamily,
      fontFamilyFallback: _uiFallback,
      fontSize: size,
      height: 1.3,
      letterSpacing: 0.1,
      fontWeight: weight,
    );
  }
}
