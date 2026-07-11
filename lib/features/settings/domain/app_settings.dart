enum AppThemePreference { dark, light, system }

/// Valid [AppSettings.defaultExportFormat] values.
/// Stored as strings to avoid importing the export feature.
abstract final class ExportFormatSetting {
  static const String docx = 'docx';
  static const String pdf = 'pdf';
  static const String both = 'both';
  static const Set<String> values = <String>{docx, pdf, both};
}

final class AppSettings {
  const AppSettings({
    required this.workspaceRoot,
    required this.theme,
    required this.recentProjectsLimit,
    required this.openRecentOnStartup,
    required this.confirmBeforeClosing,
    required this.autosaveIntervalSeconds,
    required this.defaultExportFormat,
    required this.defaultCreateZip,
  });

  factory AppSettings.defaults({required String workspaceRoot}) {
    return AppSettings(
      workspaceRoot: workspaceRoot,
      theme: SettingsDefaults.theme,
      recentProjectsLimit: SettingsDefaults.recentProjectsLimit,
      openRecentOnStartup: SettingsDefaults.openRecentOnStartup,
      confirmBeforeClosing: SettingsDefaults.confirmBeforeClosing,
      autosaveIntervalSeconds: SettingsDefaults.autosaveIntervalSeconds,
      defaultExportFormat: SettingsDefaults.defaultExportFormat,
      defaultCreateZip: SettingsDefaults.defaultCreateZip,
    );
  }

  factory AppSettings.fromJson(
    Map<String, dynamic> json, {
    required String defaultWorkspaceRoot,
  }) {
    final root = json['workspaceRoot'] as String?;
    return AppSettings(
      workspaceRoot: (root == null || root.trim().isEmpty)
          ? defaultWorkspaceRoot
          : root.trim(),
      theme: _parseTheme(json['theme'] as String?),
      recentProjectsLimit: _parseRecentLimit(json['recentProjectsLimit']),
      openRecentOnStartup:
          json['openRecentOnStartup'] as bool? ??
          SettingsDefaults.openRecentOnStartup,
      confirmBeforeClosing:
          json['confirmBeforeClosing'] as bool? ??
          SettingsDefaults.confirmBeforeClosing,
      autosaveIntervalSeconds: _parseAutosave(json['autosaveIntervalSeconds']),
      defaultExportFormat: _parseExportFormat(
        json['defaultExportFormat'] as String?,
      ),
      defaultCreateZip:
          json['defaultCreateZip'] as bool? ??
          SettingsDefaults.defaultCreateZip,
    );
  }

  final String workspaceRoot;
  final AppThemePreference theme;
  final int recentProjectsLimit;
  final bool openRecentOnStartup;
  final bool confirmBeforeClosing;

  /// Persisted only; no autosave engine yet.
  final int autosaveIntervalSeconds;
  final String defaultExportFormat;
  final bool defaultCreateZip;

  AppSettings copyWith({
    String? workspaceRoot,
    AppThemePreference? theme,
    int? recentProjectsLimit,
    bool? openRecentOnStartup,
    bool? confirmBeforeClosing,
    int? autosaveIntervalSeconds,
    String? defaultExportFormat,
    bool? defaultCreateZip,
  }) {
    return AppSettings(
      workspaceRoot: workspaceRoot ?? this.workspaceRoot,
      theme: theme ?? this.theme,
      recentProjectsLimit: recentProjectsLimit ?? this.recentProjectsLimit,
      openRecentOnStartup: openRecentOnStartup ?? this.openRecentOnStartup,
      confirmBeforeClosing: confirmBeforeClosing ?? this.confirmBeforeClosing,
      autosaveIntervalSeconds:
          autosaveIntervalSeconds ?? this.autosaveIntervalSeconds,
      defaultExportFormat: defaultExportFormat ?? this.defaultExportFormat,
      defaultCreateZip: defaultCreateZip ?? this.defaultCreateZip,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'workspaceRoot': workspaceRoot,
      'theme': theme.name,
      'recentProjectsLimit': recentProjectsLimit,
      'openRecentOnStartup': openRecentOnStartup,
      'confirmBeforeClosing': confirmBeforeClosing,
      'autosaveIntervalSeconds': autosaveIntervalSeconds,
      'defaultExportFormat': defaultExportFormat,
      'defaultCreateZip': defaultCreateZip,
    };
  }

  static AppThemePreference _parseTheme(String? name) {
    return switch (name) {
      'light' => AppThemePreference.light,
      'system' => AppThemePreference.system,
      'dark' => AppThemePreference.dark,
      _ => SettingsDefaults.theme,
    };
  }

  static int _parseRecentLimit(Object? value) {
    final parsed = switch (value) {
      final int n => n,
      final String s => int.tryParse(s),
      _ => null,
    };
    if (parsed == null || parsed < 1) {
      return SettingsDefaults.recentProjectsLimit;
    }
    return parsed.clamp(1, SettingsDefaults.maxRecentProjectsLimit);
  }

  static int _parseAutosave(Object? value) {
    final parsed = switch (value) {
      final int n => n,
      final String s => int.tryParse(s),
      _ => null,
    };
    if (parsed == null || parsed < 0) {
      return SettingsDefaults.autosaveIntervalSeconds;
    }
    return parsed;
  }

  static String _parseExportFormat(String? value) {
    if (value != null && ExportFormatSetting.values.contains(value)) {
      return value;
    }
    return SettingsDefaults.defaultExportFormat;
  }
}

abstract final class SettingsDefaults {
  static const AppThemePreference theme = AppThemePreference.dark;
  static const int recentProjectsLimit = 10;
  static const int maxRecentProjectsLimit = 50;
  static const bool openRecentOnStartup = false;
  static const bool confirmBeforeClosing = true;

  /// Reserved; no autosave engine in this sprint.
  static const int autosaveIntervalSeconds = 60;
  static const String defaultExportFormat = ExportFormatSetting.docx;
  static const bool defaultCreateZip = false;
}
