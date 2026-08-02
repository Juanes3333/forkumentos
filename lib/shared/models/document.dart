import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'document.freezed.dart';

enum DocumentOmission { image, headerFooter, footnote }

/// Alineación horizontal de un párrafo o de una tabla (`w:jc`).
enum DocumentAlignment { start, center, end, justify }

@freezed
class Document with _$Document {
  const factory Document({
    required List<DocumentPage> pages,
    required Set<DocumentOmission> omissions,
    @Default(<DocumentBlock>[]) List<DocumentBlock> header,
    @Default(<DocumentBlock>[]) List<DocumentBlock> footer,
  }) = _Document;
}

@freezed
class DocumentPage with _$DocumentPage {
  const factory DocumentPage({
    required int number,
    required double widthPoints,
    required double heightPoints,
    required DocumentMargins margins,
    required List<DocumentBlock> blocks,
  }) = _DocumentPage;
}

@freezed
class DocumentMargins with _$DocumentMargins {
  const factory DocumentMargins({
    required double topPoints,
    required double rightPoints,
    required double bottomPoints,
    required double leftPoints,
    // `w:pgMar/@header` y `@footer`: distancia desde el borde de la hoja
    // hasta donde arranca el encabezado / termina el pie. Word los usa como
    // ancla dentro del margen, no dentro del área de contenido. 36pt = 0.5",
    // el valor por defecto de Word cuando el atributo falta.
    @Default(36) double headerDistancePoints,
    @Default(36) double footerDistancePoints,
  }) = _DocumentMargins;
}

@freezed
sealed class DocumentBlock with _$DocumentBlock {
  const factory DocumentBlock.paragraph(DocumentParagraph paragraph) =
      DocumentParagraphBlock;

  const factory DocumentBlock.table(DocumentTable table) = DocumentTableBlock;
}

@freezed
class DocumentTable with _$DocumentTable {
  const factory DocumentTable({
    required List<DocumentTableRow> rows,
    // Anchos de `w:tblGrid/w:gridCol`, en el orden de las columnas. Vacío
    // cuando el DOCX no declara la retícula: el renderer reparte entonces el
    // ancho disponible en partes iguales.
    @Default(<double>[]) List<double> columnWidthsPoints,
    @Default(DocumentAlignment.start) DocumentAlignment alignment,
    // 0 = tabla sin bordes visibles (el caso por defecto en Word cuando no
    // hay `w:tblBorders` ni estilo de tabla que los aporte).
    @Default(0) double borderWidthPoints,
    String? borderColorHex,
  }) = _DocumentTable;
}

@freezed
class DocumentTableRow with _$DocumentTableRow {
  const factory DocumentTableRow({required List<DocumentTableCell> cells}) =
      _DocumentTableRow;
}

@freezed
class DocumentTableCell with _$DocumentTableCell {
  const factory DocumentTableCell({
    required List<DocumentBlock> blocks,
    double? widthPoints,
  }) = _DocumentTableCell;
}

@freezed
class DocumentParagraph with _$DocumentParagraph {
  const factory DocumentParagraph({
    required List<DocumentRun> runs,
    @Default(0) double spacingBeforePoints,
    @Default(0) double spacingAfterPoints,
    // ponytail: guardado desde la cascada de estilos pero sin consumidor
    // todavía — no se usa como restricción dura sobre dónde cortar página.
    // Mejora futura: evitar que _extractPages corte justo después de un
    // párrafo con keepWithNext=true.
    @Default(false) bool keepWithNext,
    @Default(DocumentAlignment.start) DocumentAlignment alignment,
    @Default(0) double indentLeftPoints,
    @Default(0) double indentRightPoints,
    // Sangría extra de la primera línea (`w:ind/@firstLine`). Negativa para
    // la sangría francesa (`@hanging`), que arranca la primera línea a la
    // izquierda del resto del párrafo.
    @Default(0) double indentFirstLinePoints,
    // Interlineado de `w:spacing`: múltiplo del alto natural de línea cuando
    // `w:lineRule="auto"`, o alto fijo en puntos para "exact"/"atLeast".
    // Ambos null = interlineado sencillo (el natural de la fuente).
    double? lineSpacingMultiple,
    double? lineSpacingExactPoints,
  }) = _DocumentParagraph;
}

@freezed
class DocumentRun with _$DocumentRun {
  const factory DocumentRun({
    required String text,
    required bool isBold,
    required bool isItalic,
    required bool isUnderlined,
    String? colorHex,
    double? fontSizePoints,
    String? fontFamily,
    // Cuando no es null, el run representa una imagen incrustada y su [text]
    // es vacío: la imagen se dibuja en el punto exacto del flujo de texto que
    // ocupa el run, sin desplazar los offsets de mapeo del párrafo.
    DocumentImage? image,
  }) = _DocumentRun;
}

/// Imagen incrustada en el DOCX (`word/media/...`), ya extraída a memoria.
///
/// Escrita a mano en vez de con freezed a propósito: freezed compara y hashea
/// las listas con `DeepCollectionEquality`, y aquí eso significa recorrer
/// byte a byte cada imagen del documento en cada comparación de estado de
/// Riverpod. La identidad del buffer basta — el parser crea un buffer nuevo
/// por carga — y deja `==`/`hashCode` en O(1).
@immutable
final class DocumentImage {
  const DocumentImage({
    required this.bytes,
    required this.widthPoints,
    required this.heightPoints,
  });

  final Uint8List bytes;
  final double widthPoints;
  final double heightPoints;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DocumentImage &&
            identical(other.bytes, bytes) &&
            other.widthPoints == widthPoints &&
            other.heightPoints == heightPoints;
  }

  @override
  int get hashCode =>
      Object.hash(identityHashCode(bytes), widthPoints, heightPoints);

  @override
  String toString() =>
      'DocumentImage(${bytes.length} bytes, '
      '${widthPoints}x${heightPoints}pt)';
}
