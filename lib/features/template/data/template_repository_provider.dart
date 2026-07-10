import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/template/data/docx_template_repository.dart';
import 'package:forkumentos/features/template/domain/template_repository.dart';

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return const DocxTemplateRepository();
});
