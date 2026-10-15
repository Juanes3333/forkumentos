import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Crea un libro XLSX nuevo con una hoja "Datos" cuya primera fila son los
/// encabezados dados (en negrita) y sin filas de datos: el Excel que el cliente
/// rellenará después. Para libros existentes se usa `XlsxColumnWriter`, que
/// los edita sin volver a codificarlos.
class XlsxWorkbookWriter {
  const XlsxWorkbookWriter();

  Uint8List create(List<String> headers) {
    final excel = Excel.createExcel()..rename('Sheet1', 'Datos');
    final sheet = excel['Datos'];
    final bold = CellStyle(bold: true);
    for (var column = 0; column < headers.length; column++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
        TextCellValue(headers[column]),
        cellStyle: bold,
      );
    }
    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('No se pudo codificar el libro de Excel.');
    }
    return Uint8List.fromList(encoded);
  }
}
