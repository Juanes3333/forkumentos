import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

DocumentParagraph resolveParagraph(Document document, DocumentTextPath path) {
  if (path.steps.isEmpty) {
    throw const DocumentTextPathResolutionException(
      'La ruta de texto no contiene pasos.',
    );
  }

  if (path.pageIndex < 0 || path.pageIndex >= document.pages.length) {
    throw DocumentTextPathResolutionException(
      'La ruta referencia una página inválida: ${path.pageIndex}.',
    );
  }

  final page = document.pages[path.pageIndex];
  final firstStep = path.steps.first;
  if (firstStep is! RootDocumentBlockStep) {
    throw const DocumentTextPathResolutionException(
      'El primer paso debe ser rootBlock.',
    );
  }

  if (firstStep.blockIndex < 0 || firstStep.blockIndex >= page.blocks.length) {
    throw DocumentTextPathResolutionException(
      'El rootBlock apunta a un índice fuera de rango: '
      '${firstStep.blockIndex}.',
    );
  }

  var currentBlock = page.blocks[firstStep.blockIndex];

  for (var index = 1; index < path.steps.length; index++) {
    final step = path.steps[index];
    if (step is! DocumentTableCellBlockStep) {
      throw const DocumentTextPathResolutionException(
        'Después de rootBlock solo se permiten pasos cellBlock.',
      );
    }

    if (currentBlock is! DocumentTableBlock) {
      throw DocumentTextPathResolutionException(
        'El paso ${index + 1} intenta entrar a celda '
        'pero el bloque actual no es tabla.',
      );
    }

    final rows = currentBlock.table.rows;
    if (step.rowIndex < 0 || step.rowIndex >= rows.length) {
      throw DocumentTextPathResolutionException(
        'rowIndex fuera de rango en paso ${index + 1}: ${step.rowIndex}.',
      );
    }

    final row = rows[step.rowIndex];
    if (step.cellIndex < 0 || step.cellIndex >= row.cells.length) {
      throw DocumentTextPathResolutionException(
        'cellIndex fuera de rango en paso ${index + 1}: ${step.cellIndex}.',
      );
    }

    final cell = row.cells[step.cellIndex];
    if (step.blockIndex < 0 || step.blockIndex >= cell.blocks.length) {
      throw DocumentTextPathResolutionException(
        'blockIndex fuera de rango en paso ${index + 1}: ${step.blockIndex}.',
      );
    }

    currentBlock = cell.blocks[step.blockIndex];
  }

  if (currentBlock case DocumentParagraphBlock(:final paragraph)) {
    return paragraph;
  }

  throw const DocumentTextPathResolutionException(
    'La ruta no resuelve a un párrafo.',
  );
}

final class DocumentTextPathResolutionException implements Exception {
  const DocumentTextPathResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}
