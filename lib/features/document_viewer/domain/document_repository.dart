import 'package:forkumentos/features/document_viewer/domain/document.dart';

// ignore: one_member_abstracts
abstract interface class DocumentRepository {
  Future<Document> load(String filePath);
}
