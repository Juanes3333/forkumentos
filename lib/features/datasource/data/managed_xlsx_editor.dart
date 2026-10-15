import 'dart:io';
import 'dart:typed_data';

import 'package:forkumentos/features/datasource/data/managed_datasource_store.dart';
import 'package:forkumentos/features/datasource/data/xlsx_column_writer.dart';
import 'package:forkumentos/features/datasource/data/xlsx_datasource_repository.dart';
import 'package:path/path.dart' as p;

/// El Excel está abierto en otra aplicación y no se puede escribir.
final class ExcelLockedException implements Exception {
  const ExcelLockedException(this.path);

  final String path;

  @override
  String toString() => 'El archivo está abierto en Excel: $path';
}

/// Agrega columnas al Excel gestionado de forma segura: comprueba que se
/// pueda escribir, trabaja sobre un temporal, verifica el resultado
/// releyéndolo con el mismo lector que usa la app, guarda una copia en
/// `anteriores/` y solo entonces reemplaza el archivo.
class ManagedXlsxEditor {
  const ManagedXlsxEditor({
    this.columnWriter = const XlsxColumnWriter(),
    this.store = const ManagedDatasourceStore(),
  });

  final XlsxColumnWriter columnWriter;
  final ManagedDatasourceStore store;

  /// Agrega la columna [header] al libro [path] en la posición [insertAt]
  /// (0-based, entre las columnas con encabezado).
  ///
  /// Lanza [ExcelLockedException] si el archivo está abierto en Excel,
  /// [XlsxWriteException] si no se puede modificar sin riesgo y
  /// [FileSystemException] ante otros fallos de disco. Ante cualquier fallo
  /// el archivo original queda intacto.
  Future<XlsxColumnInsertResult> addColumn({
    required String path,
    required String header,
    required int insertAt,
  }) async {
    _ensureWritable(path);

    final Uint8List original;
    try {
      original = await File(path).readAsBytes();
    } on FileSystemException catch (error) {
      throw _isLock(error) ? ExcelLockedException(path) : error;
    }
    final before = await _read(original, path);
    final result = columnWriter.insertColumn(
      xlsxBytes: original,
      header: header,
      insertAt: insertAt,
    );

    final temp = File(_auxiliaryPath(path, 'nuevo'));
    try {
      await temp.writeAsBytes(result.bytes, flush: true);
      await _verify(
        temp: temp,
        before: before,
        header: header,
        columnIndex: result.columnIndex,
      );
      await store.backUpFile(File(path));
      try {
        await temp.rename(path);
      } on FileSystemException {
        // Excel pudo abrir el archivo entre la comprobación y el reemplazo.
        throw ExcelLockedException(path);
      }
    } finally {
      if (temp.existsSync()) {
        temp.deleteSync();
      }
    }
    return result;
  }

  /// Ruta de un archivo auxiliar junto a [path] que conserva la extensión (el
  /// lector de datos la exige) y empieza por punto para pasar desapercibido.
  String _auxiliaryPath(String path, String purpose) => p.join(
    p.dirname(path),
    '.forkumentos_${purpose}_${DateTime.now().microsecondsSinceEpoch}_'
    '${p.basename(path)}',
  );

  /// Errores de Windows por archivo en uso (32) o con una parte bloqueada
  /// (33).
  bool _isLock(FileSystemException error) {
    final code = error.osError?.errorCode;
    return code == 32 || code == 33;
  }

  /// Un archivo abierto en Excel se puede leer pero no escribir.
  void _ensureWritable(String path) {
    try {
      File(path).openSync(mode: FileMode.append).closeSync();
    } on FileSystemException {
      throw ExcelLockedException(path);
    }
  }

  Future<_Snapshot> _read(Uint8List bytes, String path) async {
    final probe = File(_auxiliaryPath(path, 'lectura'))
      ..writeAsBytesSync(bytes);
    try {
      final datasource = await const XlsxDatasourceRepository().load(
        probe.path,
      );
      return _Snapshot(datasource.headers, datasource.rowCount);
    } finally {
      probe.deleteSync();
    }
  }

  /// El libro modificado debe leerse igual que el original más la columna
  /// nueva en su sitio: mismos encabezados (en el mismo orden), mismas filas.
  Future<void> _verify({
    required File temp,
    required _Snapshot before,
    required String header,
    required int columnIndex,
  }) async {
    final after = await const XlsxDatasourceRepository().load(temp.path);
    final expected = <String>[...before.headers]..insert(columnIndex, header);
    final sameHeaders =
        after.headers.length == expected.length &&
        <int>[
          for (var i = 0; i < expected.length; i++) i,
        ].every((i) => after.headers[i] == expected[i]);
    if (!sameHeaders || after.rowCount != before.rowCount) {
      throw const XlsxWriteException(
        'No se pudo agregar la columna sin riesgo de dañar el Excel; no se '
        'modificó el archivo.',
      );
    }
  }
}

final class _Snapshot {
  const _Snapshot(this.headers, this.rowCount);

  final List<String> headers;
  final int rowCount;
}
