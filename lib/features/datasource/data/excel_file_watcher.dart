import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Avisa cuando el usuario guarda el Excel gestionado.
///
/// Excel no escribe sobre el archivo: guarda en un temporal y lo renombra
/// sobre el original (y crea un `~$archivo.xlsx` mientras está abierto), así
/// que se vigila la **carpeta** y se filtra por el nombre del archivo. Un
/// guardado dispara varios eventos y OneDrive/Microsoft 365 autoguardan: se
/// espera un tiempo sin eventos ([debounce]) y a que tamaño y fecha dejen de
/// cambiar antes de avisar.
final class ExcelFileWatcher {
  ExcelFileWatcher({
    required this.filePath,
    this.debounce = const Duration(milliseconds: 1500),
    this.stabilityInterval = const Duration(milliseconds: 400),
    this.maxStabilityChecks = 8,
    this.muteTail = const Duration(milliseconds: 1500),
  });

  /// Archivo que se vigila.
  final String filePath;

  /// Tiempo sin eventos antes de comprobar el archivo.
  final Duration debounce;

  /// Pausa entre dos comprobaciones de que el archivo dejó de cambiar.
  final Duration stabilityInterval;

  /// Máximo de comprobaciones; si el archivo no se estabiliza, no se avisa
  /// ahora y el siguiente evento vuelve a intentarlo.
  final int maxStabilityChecks;

  /// Tiempo que se siguen ignorando eventos tras una escritura propia.
  final Duration muteTail;

  final StreamController<void> _controller = StreamController<void>.broadcast();
  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  int _muteDepth = 0;
  DateTime? _mutedUntil;
  bool _disposed = false;
  int _generation = 0;

  /// Un evento por cada guardado estable del archivo.
  Stream<void> get changes => _controller.stream;

  /// Empieza a vigilar. Si la carpeta no existe no hace nada.
  void start() {
    if (_disposed || _subscription != null) {
      return;
    }
    final directory = Directory(p.dirname(filePath));
    if (!directory.existsSync()) {
      return;
    }
    _subscription = directory.watch().listen(
      _onEvent,
      // Si la carpeta se borra o deja de ser accesible no hay nada que
      // avisar; el usuario puede reabrir el proyecto.
      onError: (Object _) {},
    );
  }

  /// Ejecuta [action] (una escritura de la propia app sobre el archivo) sin
  /// que sus eventos se tomen por un guardado del usuario.
  Future<T> runSilenced<T>(Future<T> Function() action) async {
    _muteDepth++;
    try {
      return await action();
    } finally {
      _muteDepth--;
      _mutedUntil = DateTime.now().add(muteTail);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _debounceTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  bool get _isMuted {
    if (_muteDepth > 0) {
      return true;
    }
    final until = _mutedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  bool _isTarget(String path) =>
      p.basename(path).toLowerCase() == p.basename(filePath).toLowerCase();

  void _onEvent(FileSystemEvent event) {
    final touchesTarget =
        _isTarget(event.path) ||
        (event is FileSystemMoveEvent &&
            event.destination != null &&
            _isTarget(event.destination!));
    if (!touchesTarget || _isMuted) {
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(_emitWhenStable()));
  }

  Future<void> _emitWhenStable() async {
    final generation = ++_generation;
    FileStat? previous;
    for (var check = 0; check < maxStabilityChecks; check++) {
      if (_disposed || generation != _generation) {
        return;
      }
      final stat = File(filePath).statSync();
      // Mientras Excel guarda el archivo puede no existir un instante.
      if (stat.type != FileSystemEntityType.notFound &&
          previous != null &&
          stat.size == previous.size &&
          stat.modified == previous.modified) {
        if (!_isMuted && !_controller.isClosed) {
          _controller.add(null);
        }
        return;
      }
      previous = stat.type == FileSystemEntityType.notFound ? null : stat;
      await Future<void>.delayed(stabilityInterval);
    }
  }
}
