import 'package:forkumentos/features/project/domain/project.dart';

abstract interface class ProjectRepository {
  Future<Project> load(String filePath);

  Future<Project> save({required Project project, required String filePath});
}
