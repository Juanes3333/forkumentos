import 'dart:io';

/// Abre un archivo con la aplicación predeterminada de Windows (Excel para un
/// `.xlsx`). Es una costura para poder sustituirla en las pruebas.
class ExcelOpener {
  const ExcelOpener();

  /// Abre [path]. Devuelve `false` si no se pudo lanzar el proceso.
  Future<bool> open(String path) async {
    try {
      await Process.start('explorer', <String>[
        path,
      ], mode: ProcessStartMode.detached);
      return true;
    } on ProcessException {
      return false;
    }
  }
}
