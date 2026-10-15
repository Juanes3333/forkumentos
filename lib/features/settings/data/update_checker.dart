import 'dart:async';
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

      final downloadUrl = selectInstallerUrl(
        assets: json['assets'] as List<Object?>?,
        version: latestVersion,
      );

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

  /// Nombre exacto del instalador que publica cada release
  /// (`OutputBaseFilename` de `installer/Forkumentos.iss`). Se construye desde
  /// la versión parseada, porque el tag puede ser `v1.8.0` o `1.8.0`.
  @visibleForTesting
  static String installerAssetName(String version) =>
      'ForkumentosSetup_v${parseVersion(version).join('.')}.exe';

  /// Devuelve la URL de descarga del instalador de [version] entre [assets],
  /// o `null` si el release no trae un asset con el nombre exacto o su URL no
  /// es `https`. Nunca se ejecuta un `.exe` cualquiera del release.
  @visibleForTesting
  static String? selectInstallerUrl({
    required List<Object?>? assets,
    required String version,
  }) {
    if (assets == null) {
      return null;
    }
    final expected = installerAssetName(version).toLowerCase();
    for (final asset in assets) {
      if (asset is! Map<String, Object?>) {
        continue;
      }
      final name = (asset['name'] as String? ?? '').toLowerCase();
      final url = asset['browser_download_url'] as String?;
      if (name == expected && url != null && url.startsWith('https://')) {
        return url;
      }
    }
    return null;
  }

  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _idleTimeout = Duration(seconds: 30);
  static const String _downloadDirPrefix = 'forkumentos_update_';

  /// Descarga el instalador desde [downloadUrl] a un directorio temporal
  /// nuevo (o a [targetDirectory]) y reporta el progreso
  /// `(bytesRecibidos, bytesTotales)` con [onProgress]; `bytesTotales` es
  /// `-1` si el servidor no informa el tamaño.
  ///
  /// Lanza [HttpException] si la respuesta no es 200 o llega incompleta, y
  /// [TimeoutException] si la conexión no se establece o el flujo se queda
  /// sin datos durante [idleTimeout]. Si la descarga falla a medias, borra el
  /// archivo parcial y el directorio temporal que creó. El instalador
  /// descargado con éxito **no** se borra: el proceso desacoplado se ejecuta
  /// desde ese archivo; las descargas viejas se limpian al iniciar la
  /// siguiente.
  static Future<File> downloadInstaller({
    required String downloadUrl,
    required String version,
    void Function(int received, int total)? onProgress,
    HttpClient? httpClient,
    Directory? targetDirectory,
    Duration connectTimeout = _connectTimeout,
    Duration idleTimeout = _idleTimeout,
  }) async {
    final client = httpClient ?? HttpClient();
    if (httpClient == null) {
      client.connectionTimeout = connectTimeout;
    }
    if (targetDirectory == null) {
      _deleteStaleDownloads();
    }
    Directory? createdDirectory;
    try {
      final request = await client
          .getUrl(Uri.parse(downloadUrl))
          .timeout(connectTimeout);
      request.headers.set('User-Agent', 'Forkumentos/$version');
      final response = await request.close().timeout(idleTimeout);
      if (response.statusCode != 200) {
        throw HttpException(
          'No se pudo descargar el instalador (HTTP ${response.statusCode})',
        );
      }

      final directory =
          targetDirectory ??
          (createdDirectory = await Directory.systemTemp.createTemp(
            _downloadDirPrefix,
          ));
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'ForkumentosSetup_v$version.exe',
      );
      final total = response.contentLength;
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.timeout(idleTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
        await sink.close();
        if (total > 0 && received != total) {
          throw HttpException(
            'Descarga incompleta ($received de $total bytes)',
          );
        }
      } on Object {
        await sink.close();
        if (file.existsSync()) {
          file.deleteSync();
        }
        rethrow;
      }
      return file;
    } on Object {
      if (createdDirectory != null && createdDirectory.existsSync()) {
        createdDirectory.deleteSync(recursive: true);
      }
      rethrow;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  /// Borra descargas de instaladores de más de una hora. Mejor esfuerzo: un
  /// instalador que sigue en ejecución o en uso simplemente no se puede
  /// borrar y se ignora.
  static void _deleteStaleDownloads() {
    try {
      final limit = DateTime.now().subtract(const Duration(hours: 1));
      for (final entity in Directory.systemTemp.listSync()) {
        if (entity is! Directory ||
            !entity.uri.pathSegments
                .where((segment) => segment.isNotEmpty)
                .last
                .startsWith(_downloadDirPrefix) ||
            entity.statSync().modified.isAfter(limit)) {
          continue;
        }
        try {
          entity.deleteSync(recursive: true);
        } on FileSystemException {
          continue;
        }
      }
    } on FileSystemException {
      return;
    }
  }

  /// Lanza [installer] en modo silencioso, desacoplado de este proceso, y
  /// cierra la app para que el instalador pueda reemplazar los binarios.
  /// El instalador vuelve a abrir Forkumentos al terminar.
  static Future<void> launchInstallerAndExit(File installer) async {
    await Process.start(installer.path, const <String>[
      '/SILENT',
    ], mode: ProcessStartMode.detached);
    exit(0);
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
