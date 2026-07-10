import 'package:forkumentos/features/datasource/data/csv_datasource_repository.dart';
import 'package:forkumentos/features/datasource/data/xlsx_datasource_repository.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/domain/datasource_repository.dart';
import 'package:path/path.dart' as p;

final class FileDatasourceRepository implements DatasourceRepository {
  const FileDatasourceRepository();

  @override
  Future<Datasource> load(String filePath) {
    final normalizedExtension = p.extension(filePath).toLowerCase();
    switch (normalizedExtension) {
      case '.csv':
        return _csvRepository.load(filePath);
      case '.xlsx':
        return _xlsxRepository.load(filePath);
      default:
        throw const FormatException(
          'Selecciona un archivo con extensión .csv o .xlsx.',
        );
    }
  }

  DatasourceRepository get _csvRepository => const CsvDatasourceRepository();

  DatasourceRepository get _xlsxRepository => const XlsxDatasourceRepository();
}
