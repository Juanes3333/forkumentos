import 'package:forkumentos/features/template/data/docx_template_repository.dart';
import 'package:forkumentos/features/template/domain/template.dart';
import 'package:forkumentos/features/template/domain/template_repository.dart';
import 'package:path/path.dart' as p;

/// Dispatches template load by file extension (.docx).
final class ExtensionTemplateRepository implements TemplateRepository {
  const ExtensionTemplateRepository({
    this.docx = const DocxTemplateRepository(),
  });

  final TemplateRepository docx;

  @override
  Future<Template> load(String filePath) {
    return switch (p.extension(filePath).toLowerCase()) {
      '.docx' => docx.load(filePath),
      _ => throw const FormatException(
        'Selecciona un archivo con extensión .docx.',
      ),
    };
  }
}
