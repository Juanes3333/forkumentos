import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_template.freezed.dart';

/// Una plantilla Word de un proyecto con varias. Cada una guarda su propio
/// mapeo contra las columnas compartidas del Excel.
///
/// Los campos del proyecto (`embeddedTemplatePath`, `mappingAssignments`)
/// siempre describen la plantilla **activa**; mientras una plantilla está
/// activa, esos campos son la fuente de verdad y los de aquí se actualizan al
/// cambiar de plantilla.
@freezed
class ProjectTemplate with _$ProjectTemplate {
  const factory ProjectTemplate({
    required String id,
    required String fileName,

    /// Ruta del DOCX en la caché del proyecto (solo en ejecución).
    String? embeddedPath,

    /// Mapeo de esta plantilla en el formato de `mappings.json`.
    @Default([]) List<Map<String, dynamic>> assignments,
  }) = _ProjectTemplate;
}
