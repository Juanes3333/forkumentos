import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';

DocumentParagraph resolveParagraph(Document document, DocumentTextPath path) {
  if (path.steps.isEmpty) {
    throw const DocumentTextPathResolutionException(
      'La ruta de texto no contiene pasos.',
    );
  }

  final firstStep = path.steps.first;
  if (firstStep is! RootDocumentBlockStep) {
    throw const DocumentTextPathResolutionException(
      'El primer paso debe ser rootBlock.',
    );
  }

  // `blockIndex` is absolute/page-agnostic (see the DocumentTextPath doc
  // comment), so the body flattens across every page before indexing.
  final bodyBlocks = <DocumentBlock>[
    for (final page in document.pages) ...page.blocks,
  ];
  if (firstStep.blockIndex < 0 || firstStep.blockIndex >= bodyBlocks.length) {
    throw DocumentTextPathResolutionException(
      'El rootBlock apunta a un índice fuera de rango: '
      '${firstStep.blockIndex}.',
    );
  }

  var currentBlock = bodyBlocks[firstStep.blockIndex];

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

/// Which `document.pages` index currently contains the block [path]
/// addresses — for UI display ("Página N") and scroll-to-page navigation.
/// Purely a rendering lookup: it has no bearing on where a replacement gets
/// written, since [path] itself is already page-agnostic (see the
/// [DocumentTextPath] doc comment).
///
/// Header/footer paths have no page of their own, so they resolve to `0` —
/// unchanged from the pre-migration behavior of pinning `pageIndex` to 0 for
/// those regions. Returns `null` if [path] doesn't resolve to a real block.
int? resolvePageNumber(Document document, DocumentTextPath path) {
  if (path.region != DocumentTextRegion.body) {
    return 0;
  }
  if (path.steps.isEmpty) {
    return null;
  }

  final firstStep = path.steps.first;
  if (firstStep is! RootDocumentBlockStep || firstStep.blockIndex < 0) {
    return null;
  }

  var remaining = firstStep.blockIndex;
  for (var pageIndex = 0; pageIndex < document.pages.length; pageIndex++) {
    final blockCount = document.pages[pageIndex].blocks.length;
    if (remaining < blockCount) {
      return pageIndex;
    }
    remaining -= blockCount;
  }
  return null;
}

final class DocumentTextPathResolutionException implements Exception {
  const DocumentTextPathResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}
