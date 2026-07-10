import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/document_viewer/data/document_repository_provider.dart';
import 'package:forkumentos/features/document_viewer/domain/document.dart';

final documentContentProvider = AsyncNotifierProvider.autoDispose
    .family<DocumentContentNotifier, Document, String>(
      DocumentContentNotifier.new,
    );

final class DocumentContentNotifier
    extends AutoDisposeFamilyAsyncNotifier<Document, String> {
  @override
  Future<Document> build(String filePath) async {
    try {
      return await ref.read(documentRepositoryProvider).load(filePath);
    } catch (error) {
      throw _classifyLoadFailure(error);
    }
  }

  DocumentViewerException _classifyLoadFailure(Object error) {
    if (error is DocumentViewerException) {
      return error;
    }

    if (error is FormatException || error is TypeError) {
      final rawMessage = error is FormatException ? error.message : null;
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        return DocumentViewerException(rawMessage);
      }

      return const DocumentViewerException(
        'El documento no tiene un formato DOCX válido.',
      );
    }

    if (error is FileSystemException) {
      return const DocumentViewerException(
        'No se pudo leer el archivo del documento seleccionado.',
      );
    }

    return const DocumentViewerException(
      'No se pudo cargar la vista del documento. Inténtalo nuevamente.',
    );
  }
}

final class DocumentViewerException implements Exception {
  const DocumentViewerException(this.message);

  final String message;

  @override
  String toString() => message;
}
