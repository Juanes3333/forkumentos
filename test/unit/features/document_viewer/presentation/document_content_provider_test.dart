import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/document_viewer/data/document_repository_provider.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_content_provider.dart';
import 'package:forkumentos/shared/models/document.dart';

import '../../../../support/fakes.dart';

void main() {
  test('carga documento exitosamente para una ruta', () async {
    final fakeRepository = FakeDocumentRepository(
      loadHandler: (filePath) async => _buildDocument(text: filePath),
    );
    final container = _buildContainer(fakeRepository);
    addTearDown(container.dispose);

    final document = await container.read(
      documentContentProvider('/tmp/plantilla.docx').future,
    );

    expect(_firstParagraphText(document.pages.single), '/tmp/plantilla.docx');
  });

  test('clasifica errores como DocumentContentException', () async {
    final fakeRepository = FakeDocumentRepository(
      loadHandler: (_) async => throw const FormatException('DOCX inválido'),
    );
    final container = _buildContainer(fakeRepository);
    addTearDown(container.dispose);

    await expectLater(
      container.read(documentContentProvider('/tmp/invalido.docx').future),
      throwsA(
        isA<DocumentContentException>().having(
          (error) => error.message,
          'message',
          'DOCX inválido',
        ),
      ),
    );
  });

  test('rutas distintas mantienen estados independientes en family', () async {
    final loadedPaths = <String>[];
    final fakeRepository = FakeDocumentRepository(
      loadHandler: (filePath) async {
        loadedPaths.add(filePath);
        return _buildDocument(text: filePath);
      },
    );
    final container = _buildContainer(fakeRepository);
    addTearDown(container.dispose);

    final first = await container.read(
      documentContentProvider('/tmp/a.docx').future,
    );
    final second = await container.read(
      documentContentProvider('/tmp/b.docx').future,
    );

    expect(_firstParagraphText(first.pages.single), '/tmp/a.docx');
    expect(_firstParagraphText(second.pages.single), '/tmp/b.docx');
    expect(
      loadedPaths,
      containsAllInOrder(<String>['/tmp/a.docx', '/tmp/b.docx']),
    );
  });

  test(
    'autoDispose vuelve a cargar tras liberar y volver a solicitar',
    () async {
      var loadCount = 0;
      final fakeRepository = FakeDocumentRepository(
        loadHandler: (_) async {
          loadCount++;
          return _buildDocument(text: 'contenido');
        },
      );
      final container = _buildContainer(fakeRepository);
      addTearDown(container.dispose);

      final provider = documentContentProvider('/tmp/auto_dispose.docx');
      final subscription = container.listen<AsyncValue<Document>>(
        provider,
        (_, __) {},
        fireImmediately: true,
      );
      await container.read(provider.future);
      expect(loadCount, 1);

      subscription.close();
      await Future<void>.delayed(Duration.zero);

      final secondSubscription = container.listen<AsyncValue<Document>>(
        provider,
        (_, __) {},
        fireImmediately: true,
      );
      await container.read(provider.future);
      expect(loadCount, 2);
      secondSubscription.close();
    },
  );
}

ProviderContainer _buildContainer(FakeDocumentRepository repository) {
  return ProviderContainer(
    overrides: <Override>[
      documentRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

Document _buildDocument({required String text}) {
  return Document(
    pages: <DocumentPage>[
      DocumentPage(
        number: 1,
        widthPoints: 612,
        heightPoints: 792,
        margins: const DocumentMargins(
          topPoints: 72,
          rightPoints: 72,
          bottomPoints: 72,
          leftPoints: 72,
        ),
        blocks: <DocumentBlock>[
          DocumentBlock.paragraph(
            DocumentParagraph(
              runs: <DocumentRun>[
                DocumentRun(
                  text: text,
                  isBold: false,
                  isItalic: false,
                  isUnderlined: false,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
    omissions: const <DocumentOmission>{},
  );
}

String _firstParagraphText(DocumentPage page) {
  for (final block in page.blocks) {
    if (block case DocumentParagraphBlock(:final paragraph)) {
      return paragraph.runs.single.text;
    }
  }

  throw StateError('La página no contiene párrafos.');
}
