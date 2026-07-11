import 'package:path/path.dart' as p;

/// Classifies a dropped/picked path for import into Forkumentos.
enum DroppedFileKind {
  docxTemplate,
  pdfTemplate,
  csvDatasource,
  xlsxDatasource,
  forkProject,
  unsupported,
}

DroppedFileKind classifyDroppedPath(String path) {
  return switch (p.extension(path).toLowerCase()) {
    '.docx' => DroppedFileKind.docxTemplate,
    '.pdf' => DroppedFileKind.pdfTemplate,
    '.csv' => DroppedFileKind.csvDatasource,
    '.xlsx' => DroppedFileKind.xlsxDatasource,
    '.fork' => DroppedFileKind.forkProject,
    _ => DroppedFileKind.unsupported,
  };
}

bool isTemplatePath(String path) {
  final kind = classifyDroppedPath(path);
  return kind == DroppedFileKind.docxTemplate ||
      kind == DroppedFileKind.pdfTemplate;
}

bool isDatasourcePath(String path) {
  final kind = classifyDroppedPath(path);
  return kind == DroppedFileKind.csvDatasource ||
      kind == DroppedFileKind.xlsxDatasource;
}

String labelForDroppedKind(DroppedFileKind kind) {
  return switch (kind) {
    DroppedFileKind.docxTemplate => 'Plantilla DOCX',
    DroppedFileKind.pdfTemplate => 'Plantilla PDF',
    DroppedFileKind.csvDatasource => 'CSV',
    DroppedFileKind.xlsxDatasource => 'XLSX',
    DroppedFileKind.forkProject => 'Proyecto .fork',
    DroppedFileKind.unsupported => 'No compatible',
  };
}
