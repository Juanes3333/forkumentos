import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/shared/import/dropped_file_kind.dart';

void main() {
  test('clasifica extensiones de importación', () {
    expect(
      classifyDroppedPath(r'C:\a\plantilla.docx'),
      DroppedFileKind.docxTemplate,
    );
    expect(
      classifyDroppedPath(r'C:\a\plantilla.PDF'),
      DroppedFileKind.pdfTemplate,
    );
    expect(
      classifyDroppedPath(r'C:\a\datos.csv'),
      DroppedFileKind.csvDatasource,
    );
    expect(
      classifyDroppedPath(r'C:\a\datos.xlsx'),
      DroppedFileKind.xlsxDatasource,
    );
    expect(
      classifyDroppedPath(r'C:\a\proyecto.fork'),
      DroppedFileKind.forkProject,
    );
    expect(classifyDroppedPath(r'C:\a\foto.png'), DroppedFileKind.unsupported);
  });
}
