import 'package:forkumentos/features/datasource/domain/datasource.dart';

// ignore: one_member_abstracts
abstract interface class DatasourceRepository {
  Future<Datasource> load(String filePath);
}
