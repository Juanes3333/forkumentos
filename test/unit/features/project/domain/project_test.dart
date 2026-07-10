import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/project/domain/project.dart';

void main() {
  test('serializa y deserializa sin persistir filePath', () {
    final project = Project(
      id: 'project-1',
      name: 'Proyecto Demo',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 1, 2),
      filePath: r'C:\temp\demo.forkumentos.json',
    );

    final json = project.toJson();
    expect(json.containsKey('filePath'), isFalse);

    final restored = Project.fromJson(json);
    expect(restored.id, project.id);
    expect(restored.name, project.name);
    expect(restored.createdAt, project.createdAt);
    expect(restored.updatedAt, project.updatedAt);
    expect(restored.filePath, isNull);
  });

  test('serializa y deserializa sin persistir isDirty', () {
    final project = Project(
      id: 'project-1',
      name: 'Proyecto Demo',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 1, 2),
      isDirty: true,
    );

    final json = project.toJson();
    expect(json.containsKey('isDirty'), isFalse);

    final restored = Project.fromJson(json);
    expect(restored.isDirty, isFalse);
  });
}
