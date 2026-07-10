import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/project/data/local_project_repository.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return const LocalProjectRepository();
});
