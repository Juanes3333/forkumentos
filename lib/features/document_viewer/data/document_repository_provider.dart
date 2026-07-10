import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/document_viewer/data/docx_document_repository.dart';
import 'package:forkumentos/features/document_viewer/domain/document_repository.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return const DocxDocumentRepository();
});
