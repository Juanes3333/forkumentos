import 'dart:io';

import 'package:forkumentos/features/template/domain/template.dart';
import 'package:forkumentos/features/template/domain/template_repository.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

final class PdfTemplateRepository implements TemplateRepository {
  const PdfTemplateRepository();

  @override
  Future<Template> load(String filePath) async {
    final normalizedExtension = p.extension(filePath).toLowerCase();
    if (normalizedExtension != '.pdf') {
      throw const FormatException('Selecciona un archivo con extensión .pdf.');
    }

    final bytes = await File(filePath).readAsBytes();
    late final PdfDocument pdf;
    try {
      pdf = PdfDocument(inputBytes: bytes);
    } catch (_) {
      throw const FormatException('El archivo no es un PDF válido.');
    }

    try {
      return Template(
        sourcePath: filePath,
        fileName: p.basename(filePath),
        fileSizeBytes: bytes.lengthInBytes,
        importedAt: DateTime.now().toUtc(),
        pageCount: pdf.pages.count,
      );
    } finally {
      pdf.dispose();
    }
  }
}
