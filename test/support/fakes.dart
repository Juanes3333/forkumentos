import 'package:forkumentos/core/logging/logging_service.dart';
import 'package:forkumentos/core/storage/key_value_storage.dart';
import 'package:forkumentos/core/window/window_service.dart';
import 'package:forkumentos/features/datasource/domain/datasource.dart';
import 'package:forkumentos/features/datasource/domain/datasource_repository.dart';
import 'package:forkumentos/features/document_viewer/domain/document.dart';
import 'package:forkumentos/features/document_viewer/domain/document_repository.dart';
import 'package:forkumentos/features/template/domain/template.dart';
import 'package:forkumentos/features/template/domain/template_repository.dart';

final class FakeLoggingService implements LoggingService {
  final List<String> entries = <String>[];

  @override
  void debug(String message, {String? module}) {
    entries.add(_format('DEBUG', message, module: module));
  }

  @override
  void info(String message, {String? module}) {
    entries.add(_format('INFO', message, module: module));
  }

  @override
  void warning(
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  }) {
    entries.add(_format('WARN', message, module: module));
  }

  @override
  void error(
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  }) {
    entries.add(_format('ERROR', message, module: module));
  }

  String _format(String level, String message, {String? module}) {
    if (module == null || module.isEmpty) {
      return '[$level] $message';
    }

    return '[$level][$module] $message';
  }
}

final class FakeKeyValueStorage implements KeyValueStorage {
  final Map<String, String> _values = <String, String>{};
  bool isInitialized = false;

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }
}

final class FakeWindowService implements WindowService {
  String? lastTitle;
  bool preventCloseActive = false;
  Future<void> Function()? registeredCloseListener;
  bool destroyed = false;

  @override
  Future<void> setTitle(String title) async {
    lastTitle = title;
  }

  @override
  Future<void> setPreventClose(bool value) async {
    preventCloseActive = value;
  }

  @override
  void addCloseListener(Future<void> Function() onCloseRequested) {
    registeredCloseListener = onCloseRequested;
  }

  @override
  Future<void> destroy() async {
    destroyed = true;
  }
}

final class FakeTemplateRepository implements TemplateRepository {
  FakeTemplateRepository({this.loadHandler});

  Future<Template> Function(String filePath)? loadHandler;

  @override
  Future<Template> load(String filePath) async {
    final handler = loadHandler;
    if (handler != null) {
      return handler(filePath);
    }

    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    return Template(
      sourcePath: filePath,
      fileName: fileName,
      fileSizeBytes: 256,
      importedAt: DateTime.utc(2026),
    );
  }
}

final class FakeDatasourceRepository implements DatasourceRepository {
  FakeDatasourceRepository({this.loadHandler});

  Future<Datasource> Function(String filePath)? loadHandler;

  @override
  Future<Datasource> load(String filePath) async {
    final handler = loadHandler;
    if (handler != null) {
      return handler(filePath);
    }

    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    return Datasource(
      sourcePath: filePath,
      fileName: fileName,
      fileSizeBytes: 256,
      importedAt: DateTime.utc(2026),
      format: DatasourceFormat.csv,
      headers: const <String>['nombre', 'correo'],
      previewRow: const <String?>['Ana', 'ana@example.com'],
      rowCount: 1,
      emptyColumnIndexes: const <int>[],
    );
  }
}

final class FakeDocumentRepository implements DocumentRepository {
  FakeDocumentRepository({this.loadHandler});

  Future<Document> Function(String filePath)? loadHandler;

  @override
  Future<Document> load(String filePath) async {
    final handler = loadHandler;
    if (handler != null) {
      return handler(filePath);
    }

    return const Document(
      pages: <DocumentPage>[
        DocumentPage(
          number: 1,
          widthPoints: 612,
          heightPoints: 792,
          margins: DocumentMargins(
            topPoints: 72,
            rightPoints: 72,
            bottomPoints: 72,
            leftPoints: 72,
          ),
          paragraphs: <DocumentParagraph>[
            DocumentParagraph(
              runs: <DocumentRun>[
                DocumentRun(
                  text: 'Documento de ejemplo',
                  isBold: false,
                  isItalic: false,
                  isUnderlined: false,
                ),
              ],
            ),
          ],
        ),
      ],
      omissions: <DocumentOmission>{},
    );
  }
}
