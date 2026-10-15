// ignore_for_file: invalid_annotation_target

import 'package:forkumentos/features/project/domain/project_template.dart';
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
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? embeddedTemplatePath,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? embeddedDatasourcePath,
    // Not part of the standard freezed toJson: LocalProjectRepository reads
    // and writes this key manually in project.json (see save()/load()),
    // consistent with how embeddedTemplatePath/embeddedDatasourcePath are
    // already handled outside the generated serializer.
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? datasourceExternalPath,
    // Fecha de modificación (ms desde epoch) y tamaño del Excel gestionado
    // tal como estaban cuando se leyó por última vez. Al abrir el proyecto,
    // si el archivo difiere, se vuelve a leer. Se leen y escriben a mano en
    // project.json, igual que datasourceExternalPath; null en proyectos
    // anteriores.
    @JsonKey(includeFromJson: false, includeToJson: false)
    int? datasourceSyncedMtimeMs,
    @JsonKey(includeFromJson: false, includeToJson: false)
    int? datasourceSyncedSizeBytes,
    // Plantillas del proyecto en el orden de las pestañas. Vacía mientras el
    // proyecto tiene una sola (formato .fork v1); con dos o más incluye
    // también la activa, y `activeTemplateId` dice cuál es. Se leen y
    // escriben a mano en LocalProjectRepository (formato .fork v2).
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<ProjectTemplate>[])
    List<ProjectTemplate> templates,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? activeTemplateId,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
}
