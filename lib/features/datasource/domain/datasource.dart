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
  }) = _Datasource;
}
