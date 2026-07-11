enum AppThemePreference { dark, light }

final class AppSettings {
  const AppSettings({required this.workspaceRoot, required this.theme});

  factory AppSettings.fromJson(
    Map<String, dynamic> json, {
    required String defaultWorkspaceRoot,
  }) {
    final themeName = json['theme'] as String?;
    final theme = themeName == AppThemePreference.light.name
        ? AppThemePreference.light
        : AppThemePreference.dark;
    final root = json['workspaceRoot'] as String?;
    return AppSettings(
      workspaceRoot: (root == null || root.trim().isEmpty)
          ? defaultWorkspaceRoot
          : root.trim(),
      theme: theme,
    );
  }

  final String workspaceRoot;
  final AppThemePreference theme;

  AppSettings copyWith({String? workspaceRoot, AppThemePreference? theme}) {
    return AppSettings(
      workspaceRoot: workspaceRoot ?? this.workspaceRoot,
      theme: theme ?? this.theme,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'workspaceRoot': workspaceRoot,
      'theme': theme.name,
    };
  }
}

abstract final class SettingsDefaults {
  static const AppThemePreference theme = AppThemePreference.dark;
}
