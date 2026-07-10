import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/shared/data/document_repository_provider.dart';
import 'package:forkumentos/shared/models/document.dart';

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

  DocumentContentException _classifyLoadFailure(Object error) {
    if (error is DocumentContentException) {
      return error;
    }

    if (error is FormatException || error is TypeError) {
      final rawMessage = error is FormatException ? error.message : null;
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        return DocumentContentException(rawMessage);
      }

      return const DocumentContentException(
        'El documento no tiene un formato DOCX válido.',
      );
    }

    if (error is FileSystemException) {
      return const DocumentContentException(
        'No se pudo leer el archivo del documento seleccionado.',
      );
    }

    return const DocumentContentException(
      'No se pudo cargar la vista del documento. Inténtalo nuevamente.',
    );
  }
}

final class DocumentContentException implements Exception {
  const DocumentContentException(this.message);

  final String message;

  @override
  String toString() => message;
}
