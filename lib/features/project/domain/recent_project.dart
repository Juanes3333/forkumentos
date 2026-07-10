import 'package:freezed_annotation/freezed_annotation.dart';

part 'recent_project.freezed.dart';
part 'recent_project.g.dart';

@freezed
class RecentProject with _$RecentProject {
  const factory RecentProject({
    required String filePath,
    required String name,
    required DateTime lastOpenedAt,
  }) = _RecentProject;

  factory RecentProject.fromJson(Map<String, dynamic> json) =>
      _$RecentProjectFromJson(json);
}
