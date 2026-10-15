import 'package:freezed_annotation/freezed_annotation.dart';

part 'datasource.freezed.dart';

enum DatasourceFormat { csv, xlsx }

@freezed
class Datasource with _$Datasource {
  const factory Datasource({
    required String sourcePath,
    required String fileName,
    required int fileSizeBytes,
    required DateTime importedAt,
    required DatasourceFormat format,
    required List<String> headers,
    required List<String?> previewRow,
    required int rowCount,
    required List<int> emptyColumnIndexes,

    /// Fecha de modificación del archivo cuando se leyó; permite detectar
    /// ediciones de valores que no cambian el tamaño ni la forma del archivo.
    DateTime? fileModifiedAt,
  }) = _Datasource;
}
