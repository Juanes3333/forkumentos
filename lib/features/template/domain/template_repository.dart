import 'package:forkumentos/features/template/domain/template.dart';

// ignore: one_member_abstracts
abstract interface class TemplateRepository {
  Future<Template> load(String filePath);
}
