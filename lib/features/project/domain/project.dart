// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

@freezed
class Project with _$Project {
  const factory Project({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> mappingAssignments,
    @JsonKey(includeFromJson: false, includeToJson: false) String? filePath,
    @Default(false)
    @JsonKey(includeFromJson: false, includeToJson: false)
    bool isDirty,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
}
