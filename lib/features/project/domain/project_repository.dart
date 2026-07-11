import 'package:forkumentos/features/project/domain/project.dart';

const projectFileExtension = '.fork';

abstract interface class ProjectRepository {
  Future<Project> load(String filePath, {required String cacheDirectory});

  Future<Project> save({
    required Project project,
    required String filePath,
    String? templateSourcePath,
    String? datasourceSourcePath,
    String? cacheDirectory,
  });
}
