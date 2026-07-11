import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/shared/data/document_repository.dart';
import 'package:forkumentos/shared/data/extension_document_repository.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return const ExtensionDocumentRepository();
});
