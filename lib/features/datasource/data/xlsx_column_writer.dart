import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// El libro no se puede modificar sin riesgo de dañarlo.
final class XlsxWriteException implements Exception {
  const XlsxWriteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resultado de [XlsxColumnWriter.insertColumn].
final class XlsxColumnInsertResult {
  const XlsxColumnInsertResult({
    required this.bytes,
    required this.columnIndex,
    required this.appendedAtEnd,
  });

  /// Contenido del libro ya modificado.
  final Uint8List bytes;

  /// Posición (0-based) que ocupa la columna nueva.
  final int columnIndex;

  /// `true` si se agregó al final y no en la posición pedida, porque el libro
  /// tiene fórmulas, tablas o nombres definidos que habría que reescribir.
  final bool appendedAtEnd;
}

/// Agrega una columna (con su encabezado) a la primera hoja con encabezados
/// de un `.xlsx` editando el XML de la hoja directamente, sin volver a
/// codificar el libro: estilos, anchos de columna, celdas combinadas,
/// validaciones y el resto de partes se conservan tal cual.
///
/// Insertar en medio desplaza las celdas, anchos, combinadas y rangos de
/// validación/filtro. Si el libro tiene fórmulas, tablas o nombres definidos
/// no se desplaza nada: la columna se agrega al final de los encabezados.
class XlsxColumnWriter {
  const XlsxColumnWriter();

  XlsxColumnInsertResult insertColumn({
    required List<int> xlsxBytes,
    required String header,
    required int insertAt,
  }) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(xlsxBytes);
    } on Object {
      throw const XlsxWriteException('El archivo no es un libro XLSX válido.');
    }

    final sheetPath = _firstSheetWithHeaders(archive);
    final sheetFile = archive.findFile(sheetPath)!;
    final document = XmlDocument.parse(
      String.fromCharCodes(
        // Los XML de Office son UTF-8.
        _utf8Decode(sheetFile.content as List<int>),
      ),
    );

    final headerRow = _row(document, 1)!;
    final headerCount = _headerCount(headerRow);
    var target = insertAt.clamp(0, headerCount);

    final needsRewrite =
        document.findAllElements('f').isNotEmpty ||
        archive.files.any((file) => file.name.startsWith('xl/tables/')) ||
        _workbookHasDefinedNames(archive);
    final appendedAtEnd = needsRewrite && target != headerCount;
    if (needsRewrite) {
      target = headerCount;
    }

    if (needsRewrite) {
      final blocked = document
          .findAllElements('c')
          .any((cell) => _column(cell.getAttribute('r')!) >= target);
      if (blocked) {
        throw const XlsxWriteException(
          'La hoja tiene datos a la derecha de los encabezados y fórmulas o '
          'tablas: agrega la columna en Excel.',
        );
      }
    } else {
      _shiftColumns(document, target);
    }

    _addHeaderCell(headerRow, target, header);
    _updateDimension(document, target);

    final updated = Archive();
    for (final file in archive.files) {
      if (file.name == sheetPath) {
        final bytes = _utf8Encode(document.toXmlString());
        updated.addFile(ArchiveFile(file.name, bytes.length, bytes));
      } else {
        updated.addFile(file);
      }
    }
    final encoded = ZipEncoder().encode(updated);
    if (encoded == null) {
      throw const XlsxWriteException('No se pudo escribir el libro XLSX.');
    }
    return XlsxColumnInsertResult(
      bytes: Uint8List.fromList(encoded),
      columnIndex: target,
      appendedAtEnd: appendedAtEnd,
    );
  }

  // --- Hoja con encabezados -------------------------------------------------

  String _firstSheetWithHeaders(Archive archive) {
    final workbook = archive.findFile('xl/workbook.xml');
    final rels = archive.findFile('xl/_rels/workbook.xml.rels');
    if (workbook == null || rels == null) {
      throw const XlsxWriteException('El libro XLSX no tiene hojas.');
    }
    final relTargets = <String, String>{
      for (final rel in XmlDocument.parse(
        String.fromCharCodes(_utf8Decode(rels.content as List<int>)),
      ).findAllElements('Relationship'))
        rel.getAttribute('Id')!: rel.getAttribute('Target')!,
    };
    final sheets = XmlDocument.parse(
      String.fromCharCodes(_utf8Decode(workbook.content as List<int>)),
    ).findAllElements('sheet');
    for (final sheet in sheets) {
      final relId = sheet.attributes
          .firstWhere((attribute) => attribute.name.local == 'id')
          .value;
      final target = relTargets[relId];
      if (target == null) {
        continue;
      }
      final path = target.startsWith('/')
          ? target.substring(1)
          : p.posix.normalize(p.posix.join('xl', target));
      final file = archive.findFile(path);
      if (file == null) {
        continue;
      }
      final document = XmlDocument.parse(
        String.fromCharCodes(_utf8Decode(file.content as List<int>)),
      );
      final first = _row(document, 1);
      if (first != null && _headerCount(first) > 0) {
        return path;
      }
    }
    throw const XlsxWriteException(
      'No se encontró una hoja con encabezados en el libro.',
    );
  }

  bool _workbookHasDefinedNames(Archive archive) {
    final workbook = archive.findFile('xl/workbook.xml');
    if (workbook == null) {
      return false;
    }
    return XmlDocument.parse(
      String.fromCharCodes(_utf8Decode(workbook.content as List<int>)),
    ).findAllElements('definedName').isNotEmpty;
  }

  XmlElement? _row(XmlDocument document, int rowNumber) {
    for (final row in document.findAllElements('row')) {
      if (row.getAttribute('r') == '$rowNumber') {
        return row;
      }
    }
    return null;
  }

  /// Número de columnas de encabezado: hasta la última celda con contenido
  /// de la fila 1 (como hace el lector de datos, que recorta las vacías).
  int _headerCount(XmlElement headerRow) {
    var count = 0;
    for (final cell in headerRow.findElements('c')) {
      final hasContent =
          cell.getElement('v') != null || cell.getElement('is') != null;
      if (hasContent) {
        final column = _column(cell.getAttribute('r')!) + 1;
        if (column > count) {
          count = column;
        }
      }
    }
    return count;
  }

  // --- Desplazamiento de columnas ------------------------------------------

  void _shiftColumns(XmlDocument document, int at) {
    for (final cell in document.findAllElements('c')) {
      final ref = cell.getAttribute('r')!;
      cell.setAttribute('r', _shiftCellRef(ref, at));
    }
    for (final row in document.findAllElements('row')) {
      // `spans` es solo una pista de optimización y es opcional.
      row.removeAttribute('spans');
    }
    for (final column in document.findAllElements('col')) {
      final min = int.parse(column.getAttribute('min')!);
      final max = int.parse(column.getAttribute('max')!);
      final insertColumn = at + 1; // 1-based
      if (min >= insertColumn) {
        column
          ..setAttribute('min', '${min + 1}')
          ..setAttribute('max', '${max + 1}');
      } else if (max >= insertColumn) {
        column.setAttribute('max', '${max + 1}');
      }
    }
    for (final element in document.descendants.whereType<XmlElement>()) {
      for (final name in const <String>['ref', 'sqref', 'activeCell']) {
        final value = element.getAttribute(name);
        if (value != null && _isRangeAttribute(element, name)) {
          element.setAttribute(name, _shiftRangeList(value, at));
        }
      }
    }
  }

  bool _isRangeAttribute(XmlElement element, String attribute) {
    return switch (element.name.local) {
      'dimension' || 'mergeCell' || 'autoFilter' || 'hyperlink' => true,
      'conditionalFormatting' || 'dataValidation' => attribute == 'sqref',
      'selection' => true,
      _ => false,
    };
  }

  String _shiftRangeList(String value, int at) => value
      .split(' ')
      .map(
        (range) =>
            range.split(':').map((cell) => _shiftCellRef(cell, at)).join(':'),
      )
      .join(' ');

  String _shiftCellRef(String ref, int at) {
    final match = RegExp(r'^(\$?)([A-Z]+)(\$?)(\d+)$').firstMatch(ref);
    if (match == null) {
      return ref;
    }
    final column = _column(match.group(2)!);
    if (column < at) {
      return ref;
    }
    return '${match.group(1)}${_letters(column + 1)}'
        '${match.group(3)}${match.group(4)}';
  }

  // --- Encabezado nuevo -----------------------------------------------------

  void _addHeaderCell(XmlElement headerRow, int column, String header) {
    final neighbour = headerRow
        .findElements('c')
        .where((cell) => _column(cell.getAttribute('r')!) == column - 1)
        .firstOrNull;
    final style = neighbour?.getAttribute('s');
    final cell = XmlElement(
      XmlName('c'),
      <XmlAttribute>[
        XmlAttribute(XmlName('r'), '${_letters(column)}1'),
        if (style != null) XmlAttribute(XmlName('s'), style),
        XmlAttribute(XmlName('t'), 'inlineStr'),
      ],
      <XmlNode>[
        XmlElement(XmlName('is'), const <XmlAttribute>[], <XmlNode>[
          XmlElement(
            XmlName('t'),
            header != header.trim()
                ? <XmlAttribute>[
                    XmlAttribute(XmlName('space', 'xml'), 'preserve'),
                  ]
                : const <XmlAttribute>[],
            <XmlNode>[XmlText(header)],
          ),
        ]),
      ],
    );

    final cells = headerRow.children.whereType<XmlElement>().toList();
    final after = cells
        .where((existing) => _column(existing.getAttribute('r')!) > column)
        .firstOrNull;
    if (after == null) {
      headerRow.children.add(cell);
    } else {
      headerRow.children.insert(headerRow.children.indexOf(after), cell);
    }
  }

  void _updateDimension(XmlDocument document, int column) {
    final dimension = document.findAllElements('dimension').firstOrNull;
    if (dimension == null) {
      return;
    }
    final ref = dimension.getAttribute('ref');
    if (ref == null) {
      return;
    }
    final parts = ref.split(':');
    final last = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(parts.last);
    if (last == null) {
      return;
    }
    if (_column(last.group(1)!) < column) {
      parts[parts.length - 1] = '${_letters(column)}${last.group(2)}';
      dimension.setAttribute('ref', parts.join(':'));
    }
  }

  // --- Utilidades -----------------------------------------------------------

  int _column(String cellRef) {
    final letters = RegExp('^[A-Z]+').firstMatch(cellRef)!.group(0)!;
    var value = 0;
    for (final unit in letters.codeUnits) {
      value = value * 26 + (unit - 64);
    }
    return value - 1;
  }

  String _letters(int index) {
    var result = '';
    var n = index;
    while (n >= 0) {
      result = String.fromCharCode(65 + n % 26) + result;
      n = n ~/ 26 - 1;
    }
    return result;
  }

  /// UTF-8 → unidades de código UTF-16 (los XML de Office son UTF-8).
  List<int> _utf8Decode(List<int> bytes) => utf8.decode(bytes).codeUnits;

  List<int> _utf8Encode(String text) => utf8.encode(text);
}
