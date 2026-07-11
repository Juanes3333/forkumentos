import 'package:flutter/material.dart';
import 'package:forkumentos/core/theme/app_colors.dart';
import 'package:forkumentos/core/theme/app_typography.dart';

final class AppTheme {
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          surface: colors.surface,
          surfaceContainerLowest: colors.backgroundPrimary,
          surfaceContainerLow: colors.backgroundSecondary,
          surfaceContainer: colors.surface,
          surfaceContainerHigh: colors.backgroundSecondary,
          surfaceContainerHighest: colors.backgroundSecondary,
          error: colors.error,
          outline: colors.border,
          primary: colors.accent,
          secondary: colors.accent,
          tertiary: colors.warning,
          onSurface: colors.foregroundPrimary,
          onSurfaceVariant: colors.foregroundMuted,
          onPrimary: brightness == Brightness.dark
              ? colors.foregroundPrimary
              : Colors.white,
          onSecondary: brightness == Brightness.dark
              ? colors.foregroundPrimary
              : Colors.white,
          onError: Colors.white,
        );

    const compactRadius = BorderRadius.all(Radius.circular(3));
    const panelRadius = BorderRadius.all(Radius.circular(8));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.backgroundPrimary,
      canvasColor: colors.backgroundPrimary,
      dividerColor: colors.border,
      textTheme: AppTypography.dense.apply(
        bodyColor: colors.foregroundPrimary,
        displayColor: colors.foregroundPrimary,
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        surfaceTintColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: panelRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: panelRadius),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colors.backgroundSecondary,
        foregroundColor: colors.foregroundPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.backgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide(color: colors.accent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: compactRadius),
          backgroundColor: colors.accent,
          foregroundColor: brightness == Brightness.dark
              ? colors.foregroundPrimary
              : Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: compactRadius),
          side: BorderSide(color: colors.border),
          foregroundColor: colors.foregroundPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: compactRadius),
          foregroundColor: colors.accent,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accent;
          }
          return colors.foregroundMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accent.withValues(alpha: 0.35);
          }
          return colors.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(
          brightness == Brightness.dark
              ? colors.foregroundPrimary
              : Colors.white,
        ),
        side: BorderSide(color: colors.border),
      ),
      listTileTheme: ListTileThemeData(
        textColor: colors.foregroundPrimary,
        iconColor: colors.foregroundMuted,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.accent,
        unselectedLabelColor: colors.foregroundMuted,
        indicatorColor: colors.accent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: colors.surface,
      ),
    );
  }
}
