import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Resultado de la verificación de actualizaciones contra GitHub Releases.
final class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.isUpdateAvailable,
    this.releaseNotes,
    this.downloadUrl,
    this.htmlUrl,
    this.publishedAt,
  });

  /// Versión actualmente instalada / en ejecución.
  final String currentVersion;

  /// Última versión disponible en GitHub Releases.
  final String latestVersion;

  /// `true` si [latestVersion] es estrictamente mayor que [currentVersion].
  final bool isUpdateAvailable;

  /// Notas de la versión (cuerpo del release en GitHub).
  final String? releaseNotes;

  /// URL directa al `.exe` del installer (asset del release).
  final String? downloadUrl;

  /// URL de la página del release en GitHub (fallback si no hay asset).
  final String? htmlUrl;

  /// Fecha de publicación del release.
  final DateTime? publishedAt;
}

/// Consulta la API de GitHub Releases para verificar si hay una versión más
/// reciente de Forkumentos.
final class UpdateChecker {
  const UpdateChecker._();

  static const String _owner = 'Juanes3333';
  static const String _repo = 'forkumentos';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Compara la versión instalada contra la última release de GitHub.
  ///
  /// Lanza [SocketException] o [HttpException] si no hay conexión o la API
  /// falla. El caller debe capturar esos errores y mostrar un mensaje
  /// apropiado al usuario.
  static Future<UpdateCheckResult> check({
    required String currentVersion,
    HttpClient? httpClient,
  }) async {
    final client = httpClient ?? HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_apiUrl));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('User-Agent', 'Forkumentos/$currentVersion');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException(
          'GitHub API respondió con código ${response.statusCode}',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, Object?>;

      final tagName = (json['tag_name'] as String?) ?? '';
      // Los tags pueden ser "v1.7.0" o "1.7.0" — normalizar quitando la "v".
      final latestVersion = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;
      final releaseNotes = json['body'] as String?;
      final htmlUrl = json['html_url'] as String?;
      final publishedAt = json['published_at'] as String?;

      // Buscar el asset .exe del installer entre los assets del release.
      String? downloadUrl;
      final assets = json['assets'] as List<Object?>?;
      if (assets != null) {
        for (final asset in assets) {
          if (asset is Map<String, Object?>) {
            final name = asset['name'] as String? ?? '';
            if (name.toLowerCase().endsWith('.exe')) {
              downloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }
      }

      final isNewer = isNewerVersion(
        current: currentVersion,
        latest: latestVersion,
      );

      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        isUpdateAvailable: isNewer,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
        htmlUrl: htmlUrl,
        publishedAt: publishedAt != null
            ? DateTime.tryParse(publishedAt)
            : null,
      );
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  /// Compara dos versiones semánticas (major.minor.patch).
  /// Devuelve `true` si [latest] es estrictamente mayor que [current].
  @visibleForTesting
  static bool isNewerVersion({
    required String current,
    required String latest,
  }) {
    final currentParts = parseVersion(current);
    final latestParts = parseVersion(latest);
    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Parsea "1.6.0" → [1, 6, 0]. Si falla, devuelve [0, 0, 0].
  @visibleForTesting
  static List<int> parseVersion(String version) {
    final clean = version.contains('+') ? version.split('+').first : version;
    final parts = clean.split('.');
    return List<int>.generate(3, (i) {
      if (i >= parts.length) return 0;
      return int.tryParse(parts[i]) ?? 0;
    });
  }
}
