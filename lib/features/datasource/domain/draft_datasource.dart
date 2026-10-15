import 'package:forkumentos/features/datasource/domain/datasource.dart';

/// Fuente de datos "borrador": mientras el proyecto no tiene Excel, los
/// campos creados sobre el documento se exponen como encabezados de una
/// fuente sin archivo (ni filas), de modo que el mapeo funciona igual y el
/// Excel se genera después a partir de ellos.
Datasource draftDatasource(List<String> headers) {
  return Datasource(
    sourcePath: '',
    fileName: 'Campos nuevos (sin Excel)',
    fileSizeBytes: 0,
    importedAt: DateTime.now().toUtc(),
    format: DatasourceFormat.xlsx,
    headers: headers,
    previewRow: List<String?>.filled(headers.length, null),
    rowCount: 0,
    emptyColumnIndexes: <int>[for (var i = 0; i < headers.length; i++) i],
  );
}

extension DraftDatasource on Datasource {
  /// `true` si es la fuente borrador: no hay archivo detrás.
  bool get isDraft => sourcePath.isEmpty;
}
