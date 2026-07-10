import 'package:forkumentos/shared/models/document.dart';

// ignore: one_member_abstracts
abstract interface class DocumentRepository {
  Future<Document> load(String filePath);
}
