import 'package:flutter/material.dart';

/// Semantic workbench colors. Prefer [AppColors.of] so light/dark switch.
@immutable
final class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.surface,
    required this.border,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.foregroundPrimary,
    required this.foregroundMuted,
  });

  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color surface;
  final Color border;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color foregroundPrimary;
  final Color foregroundMuted;

  static const AppColors dark = AppColors(
    backgroundPrimary: Color(0xFF12151A),
    backgroundSecondary: Color(0xFF171B22),
    surface: Color(0xFF1D232B),
    border: Color(0xFF2A323C),
    accent: Color(0xFF5A86FF),
    success: Color(0xFF4CAF7D),
    warning: Color(0xFFE0A857),
    error: Color(0xFFDC6E73),
    foregroundPrimary: Color(0xFFE8EDF5),
    foregroundMuted: Color(0xFF9CA9BA),
  );

  /// Microsoft Office–inspired light workbench palette.
  static const AppColors light = AppColors(
    backgroundPrimary: Color(0xFFF3F3F3),
    backgroundSecondary: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFD1D1D1),
    accent: Color(0xFF2B579A),
    success: Color(0xFF107C10),
    warning: Color(0xFFFFB900),
    error: Color(0xFFD13438),
    foregroundPrimary: Color(0xFF242424),
    foregroundMuted: Color(0xFF616161),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? AppColors.dark;
  }

  @override
  AppColors copyWith({
    Color? backgroundPrimary,
    Color? backgroundSecondary,
    Color? surface,
    Color? border,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
    Color? foregroundPrimary,
    Color? foregroundMuted,
  }) {
    return AppColors(
      backgroundPrimary: backgroundPrimary ?? this.backgroundPrimary,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      foregroundPrimary: foregroundPrimary ?? this.foregroundPrimary,
      foregroundMuted: foregroundMuted ?? this.foregroundMuted,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      backgroundPrimary: Color.lerp(
        backgroundPrimary,
        other.backgroundPrimary,
        t,
      )!,
      backgroundSecondary: Color.lerp(
        backgroundSecondary,
        other.backgroundSecondary,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      foregroundPrimary: Color.lerp(
        foregroundPrimary,
        other.foregroundPrimary,
        t,
      )!,
      foregroundMuted: Color.lerp(foregroundMuted, other.foregroundMuted, t)!,
    );
  }
}
