import 'package:forkumentos/shared/data/document_repository.dart';
import 'package:forkumentos/shared/data/docx_document_repository.dart';
import 'package:forkumentos/shared/data/pdf_document_repository.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:path/path.dart' as p;

/// Dispatches document load by file extension (.docx / .pdf).
final class ExtensionDocumentRepository implements DocumentRepository {
  const ExtensionDocumentRepository({
    this.docx = const DocxDocumentRepository(),
    this.pdf = const PdfDocumentRepository(),
  });

  final DocumentRepository docx;
  final DocumentRepository pdf;

  @override
  Future<Document> load(String filePath) {
    return switch (p.extension(filePath).toLowerCase()) {
      '.docx' => docx.load(filePath),
      '.pdf' => pdf.load(filePath),
      _ => throw const FormatException(
        'Selecciona un archivo con extensión .docx o .pdf.',
      ),
    };
  }
}
