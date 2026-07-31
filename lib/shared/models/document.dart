import 'package:freezed_annotation/freezed_annotation.dart';

part 'document.freezed.dart';

enum DocumentOmission { image, headerFooter, footnote }

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
  const factory DocumentTable({required List<DocumentTableRow> rows}) =
      _DocumentTable;
}

@freezed
class DocumentTableRow with _$DocumentTableRow {
  const factory DocumentTableRow({required List<DocumentTableCell> cells}) =
      _DocumentTableRow;
}

@freezed
class DocumentTableCell with _$DocumentTableCell {
  const factory DocumentTableCell({required List<DocumentBlock> blocks}) =
      _DocumentTableCell;
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
  }) = _DocumentRun;
}
