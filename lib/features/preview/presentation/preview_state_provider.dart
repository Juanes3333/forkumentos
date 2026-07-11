import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/presentation/active_datasource_provider.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/preview/data/preview_record_repository.dart';
import 'package:forkumentos/features/preview/domain/preview_document.dart';
import 'package:forkumentos/features/template/presentation/active_template_provider.dart';
import 'package:forkumentos/shared/models/document.dart';
import 'package:forkumentos/shared/providers/active_project_provider.dart';
import 'package:forkumentos/shared/providers/document_content_provider.dart';

final previewStateProvider =
    NotifierProvider<PreviewStateNotifier, PreviewState>(
      PreviewStateNotifier.new,
    );

final previewRecordProvider = FutureProvider<List<String?>>((ref) async {
  final datasource = ref.watch(activeDatasourceProvider).valueOrNull;
  if (datasource == null) {
    return const <String?>[];
  }

  final rowIndex = ref.watch(
    previewStateProvider.select((state) => state.rowIndex),
  );
  return ref
      .watch(previewRecordRepositoryProvider)
      .readRecord(datasource: datasource, rowIndex: rowIndex);
});

final previewDocumentProvider = Provider<AsyncValue<Document?>>((ref) {
  final template = ref.watch(activeTemplateProvider).valueOrNull;
  if (template == null) {
    return const AsyncData<Document?>(null);
  }

  final baseDocument = ref.watch(documentContentProvider(template.sourcePath));
  final datasource = ref.watch(activeDatasourceProvider).valueOrNull;
  final assignments = ref.watch(activeMappingProvider).state.assignments;
  final previewRow = ref.watch(previewRecordProvider);

  final previewDocument = previewRow.whenData((row) {
    final document = baseDocument.valueOrNull;
    if (document == null || datasource == null || assignments.isEmpty) {
      return document;
    }
    return buildPreviewDocument(
      document: document,
      assignments: assignments,
      headers: datasource.headers,
      row: row,
    );
  });

  if (baseDocument.isLoading && baseDocument.valueOrNull == null) {
    return const AsyncLoading<Document?>();
  }

  if (baseDocument.hasError && baseDocument.valueOrNull == null) {
    return AsyncError<Document?>(baseDocument.error!, baseDocument.stackTrace!);
  }

  final previousDocument = baseDocument.valueOrNull;
  if (previewDocument.isLoading) {
    return const AsyncLoading<Document?>().copyWithPrevious(
      AsyncData(previousDocument),
    );
  }

  if (previewDocument.hasError) {
    return AsyncError<Document?>(
      previewDocument.error!,
      previewDocument.stackTrace!,
    ).copyWithPrevious(AsyncData(previousDocument));
  }

  return AsyncData(previewDocument.valueOrNull ?? previousDocument);
});

final class PreviewStateNotifier extends Notifier<PreviewState> {
  @override
  PreviewState build() {
    ref
      ..listen<String?>(
        activeProjectProvider.select((state) => state.valueOrNull?.id),
        (previous, next) {
          if (previous == next) {
            return;
          }
          state = const PreviewState();
        },
      )
      ..listen<Datasource?>(
        activeDatasourceProvider.select((state) => state.valueOrNull),
        (previous, next) {
          final previousPath = previous?.sourcePath;
          final nextPath = next?.sourcePath;
          if (previousPath == nextPath) {
            return;
          }
          state = const PreviewState();
        },
      );

    return const PreviewState();
  }

  void previousRow() {
    if (state.rowIndex == 0) {
      return;
    }
    state = state.copyWith(
      rowIndex: state.rowIndex - 1,
      previewGeneration: state.previewGeneration + 1,
    );
  }

  void nextRow(int rowCount) {
    if (rowCount <= 0 || state.rowIndex >= rowCount - 1) {
      return;
    }
    state = state.copyWith(
      rowIndex: state.rowIndex + 1,
      previewGeneration: state.previewGeneration + 1,
    );
  }

  void selectRow(int rowIndex, int rowCount) {
    if (rowCount <= 0) {
      if (state.rowIndex == 0) {
        return;
      }
      state = state.copyWith(
        rowIndex: 0,
        previewGeneration: state.previewGeneration + 1,
      );
      return;
    }

    final normalized = rowIndex.clamp(0, rowCount - 1);
    if (normalized == state.rowIndex) {
      return;
    }
    state = state.copyWith(
      rowIndex: normalized,
      previewGeneration: state.previewGeneration + 1,
    );
  }

  Future<void> refresh() async {
    if (state.isRefreshing) {
      return;
    }

    state = state.copyWith(isRefreshing: true);
    try {
      final template = ref.read(activeTemplateProvider).valueOrNull;
      if (template != null) {
        ref.invalidate(documentContentProvider(template.sourcePath));
        await ref.read(documentContentProvider(template.sourcePath).future);
      }
      ref.invalidate(previewRecordProvider);
      await ref.read(previewRecordProvider.future);
    } catch (error) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: error.toString(),
      );
      return;
    }

    state = state.copyWith(
      isRefreshing: false,
      previewGeneration: state.previewGeneration + 1,
    );
  }
}

final class PreviewState {
  const PreviewState({
    this.rowIndex = 0,
    this.previewGeneration = 0,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final int rowIndex;

  /// Bumped on refresh and row changes so the preview viewer remounts.
  final int previewGeneration;
  final bool isRefreshing;
  final String? errorMessage;

  PreviewState copyWith({
    int? rowIndex,
    int? previewGeneration,
    bool? isRefreshing,
    String? errorMessage,
  }) {
    return PreviewState(
      rowIndex: rowIndex ?? this.rowIndex,
      previewGeneration: previewGeneration ?? this.previewGeneration,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage,
    );
  }
}
