import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/data/file_datasource_repository.dart';
import 'package:forkumentos/features/datasource/domain/datasource_repository.dart';

final datasourceRepositoryProvider = Provider<DatasourceRepository>((ref) {
  return const FileDatasourceRepository();
});
