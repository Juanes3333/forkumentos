import 'dart:io';

import 'package:path/path.dart' as p;

/// Operaciones de archivo del Excel que la app gestiona por proyecto: copiarlo
/// a su carpeta (sin tocar el original del usuario) y conservar las últimas
/// versiones reemplazadas.
class ManagedDatasourceStore {
  const ManagedDatasourceStore({this.keepBackups = 5});

  /// Nombre de la subcarpeta de la carpeta gestionada con las versiones
  /// reemplazadas.
  static const String backupsFolderName = 'anteriores';

  /// Cuántas versiones anteriores se conservan.
  final int keepBackups;

  /// `true` si [path] está dentro de la carpeta gestionada [folder].
  bool isManaged(String path, String folder) => p.isWithin(folder, path);

  /// Copia [sourcePath] a [folder] conservando su nombre y devuelve la ruta
  /// gestionada. Si ya había un archivo con ese nombre, antes guarda una copia
  /// en `anteriores/` (se conservan las últimas [keepBackups]).
  ///
  /// Si [sourcePath] ya es el archivo gestionado no hace nada. Lanza
  /// [FileSystemException] si el origen no existe o el destino está bloqueado
  /// (por ejemplo, abierto en Excel).
  Future<String> adopt({
    required String sourcePath,
    required String folder,
  }) async {
    final destination = p.join(folder, p.basename(sourcePath));
    if (p.equals(sourcePath, destination)) {
      return destination;
    }
    if (!File(sourcePath).existsSync()) {
      throw FileSystemException('El archivo no existe', sourcePath);
    }

    await Directory(folder).create(recursive: true);
    final target = File(destination);
    if (target.existsSync()) {
      await _backUp(target, folder);
    }
    await File(sourcePath).copy(destination);
    return destination;
  }

  /// Guarda una copia de [current] en `anteriores/` junto a él (antes de
  /// modificarlo).
  Future<void> backUpFile(File current) =>
      _backUp(current, p.dirname(current.path));

  Future<void> _backUp(File current, String folder) async {
    final backups = Directory(p.join(folder, backupsFolderName));
    await backups.create(recursive: true);
    final stamp = _stamp(DateTime.now());
    await current.copy(
      p.join(backups.path, '${stamp}_${p.basename(current.path)}'),
    );
    await _prune(backups);
  }

  Future<void> _prune(Directory backups) async {
    final files = backups.listSync().whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in files.skip(keepBackups)) {
      try {
        await old.delete();
      } on FileSystemException {
        // Mejor esfuerzo: una copia antigua que no se puede borrar se deja.
        continue;
      }
    }
  }

  static String _stamp(DateTime moment) {
    String two(int value) => value.toString().padLeft(2, '0');
    final millis = moment.millisecond.toString().padLeft(3, '0');
    return '${moment.year}${two(moment.month)}${two(moment.day)}-'
        '${two(moment.hour)}${two(moment.minute)}${two(moment.second)}-'
        '$millis';
  }
}
