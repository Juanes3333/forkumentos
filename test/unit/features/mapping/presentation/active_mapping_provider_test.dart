import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/logging/logging_providers.dart';
import 'package:forkumentos/features/mapping/presentation/active_mapping_provider.dart';
import 'package:forkumentos/features/project/data/project_repository_provider.dart';
import 'package:forkumentos/features/project/domain/project.dart';
import 'package:forkumentos/features/project/domain/project_repository.dart';
import 'package:forkumentos/shared/models/document_text_path.dart';
import 'package:forkumentos/shared/models/document_viewer_overlay.dart';

import '../../../../support/fakes.dart';

void main() {
  test('confirmAssignment agrega asignación y avanza al siguiente campo', () {
    final container = _createContainer();
    addTearDown(container.dispose);

    container
        .read(activeMappingProvider.notifier)
        .confirmAssignment(
          selection: const DocumentTextSelection(
            path: DocumentTextPath(
              pageIndex: 0,
              steps: <DocumentPathStep>[
                DocumentPathStep.rootBlock(blockIndex: 0),
              ],
            ),
            startOffset: 0,
            endOffset: 3,
            selectedText: 'Ana',
          ),
          fieldHeader: 'nombre',
          fieldIndex: 0,
          headerCount: 2,
        );

    final session = container.read(activeMappingProvider);
    expect(session.state.assignments, hasLength(1));
    expect(session.state.assignments.single.fieldHeader, 'nombre');
    expect(session.state.currentFieldIndex, 1);
    expect(session.canUndo, isTrue);
  });

  test('undo y redo restauran asignaciones', () {
    final container = _createContainer();
    addTearDown(container.dispose);

    const selection = DocumentTextSelection(
      path: DocumentTextPath(
        pageIndex: 0,
        steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 0)],
      ),
      startOffset: 0,
      endOffset: 3,
      selectedText: 'Ana',
    );

    final notifier = container.read(activeMappingProvider.notifier)
      ..confirmAssignment(
        selection: selection,
        fieldHeader: 'nombre',
        fieldIndex: 0,
        headerCount: 2,
      )
      ..confirmAssignment(
        selection: selection,
        fieldHeader: 'correo',
        fieldIndex: 1,
        headerCount: 2,
      );
    expect(
      container.read(activeMappingProvider).state.assignments,
      hasLength(2),
    );

    notifier.undo();
    expect(
      container.read(activeMappingProvider).state.assignments,
      hasLength(1),
    );
    expect(container.read(activeMappingProvider).canRedo, isTrue);

    notifier.redo();
    expect(
      container.read(activeMappingProvider).state.assignments,
      hasLength(2),
    );
  });

  test('removeAssignmentsForField elimina todas las ocurrencias del campo', () {
    final container = _createContainer();
    addTearDown(container.dispose);

    const path = DocumentTextPath(
      pageIndex: 0,
      steps: <DocumentPathStep>[DocumentPathStep.rootBlock(blockIndex: 0)],
    );
    container.read(activeMappingProvider.notifier)
      ..confirmAssignment(
        selection: const DocumentTextSelection(
          path: path,
          startOffset: 0,
          endOffset: 3,
          selectedText: 'Ana',
        ),
        fieldHeader: 'nombre',
        fieldIndex: 0,
        headerCount: 1,
      )
      ..removeAssignmentsForField(0);

    expect(container.read(activeMappingProvider).state.assignments, isEmpty);
    expect(container.read(activeMappingProvider).canUndo, isTrue);
  });
}

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: <Override>[
      loggingServiceProvider.overrideWithValue(FakeLoggingService()),
      projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
    ],
  );
}

final class _FakeProjectRepository implements ProjectRepository {
  @override
  Future<Project> load(String filePath) async {
    return Project(
      id: 'project-mapping',
      name: 'Proyecto Mapping',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      filePath: filePath,
    );
  }

  @override
  Future<Project> save({
    required Project project,
    required String filePath,
  }) async {
    return project.copyWith(
      filePath: filePath,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
