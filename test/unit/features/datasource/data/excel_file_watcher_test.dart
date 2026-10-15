import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/datasource/data/excel_file_watcher.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late File target;
  late ExcelFileWatcher watcher;
  late List<int> emissions;
  late StreamSubscription<void> subscription;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'forkumentos_excel_watcher_test_',
    );
    target = File(p.join(directory.path, 'clientes.xlsx'))
      ..writeAsStringSync('v0');
    watcher = ExcelFileWatcher(
      filePath: target.path,
      debounce: const Duration(milliseconds: 150),
      stabilityInterval: const Duration(milliseconds: 60),
      muteTail: const Duration(milliseconds: 100),
    );
    emissions = <int>[];
    subscription = watcher.changes.listen((_) => emissions.add(1));
    watcher.start();
    // El observador de Windows tarda un instante en quedar activo.
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });

  tearDown(() async {
    await subscription.cancel();
    await watcher.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 900));

  test('guardar el archivo avisa una vez', () async {
    target.writeAsStringSync('v1');

    await settle();

    expect(emissions, hasLength(1));
  });

  test('una ráfaga de escrituras se junta en un solo aviso', () async {
    for (var i = 1; i <= 5; i++) {
      target.writeAsStringSync('v$i');
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }

    await settle();

    expect(emissions, hasLength(1));
  });

  test(
    'un reemplazo atómico (temporal + renombrar) como el de Excel avisa',
    () async {
      File(p.join(directory.path, 'ABCD1234.tmp'))
        ..writeAsStringSync('v-nueva')
        ..renameSync(target.path);

      await settle();

      expect(target.readAsStringSync(), 'v-nueva');
      expect(emissions, hasLength(1));
    },
  );

  test('borrar y volver a crear el archivo avisa una vez', () async {
    target.deleteSync();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    target.writeAsStringSync('v-recreada');

    await settle();

    expect(emissions, hasLength(1));
  });

  test(r'otros archivos y el bloqueo ~$ de Excel no avisan', () async {
    File(p.join(directory.path, r'~$clientes.xlsx')).writeAsStringSync('lock');
    File(p.join(directory.path, 'otro.xlsx')).writeAsStringSync('x');

    await settle();

    expect(emissions, isEmpty);
  });

  test('las escrituras propias dentro de runSilenced no avisan', () async {
    await watcher.runSilenced(() async {
      target.writeAsStringSync('escritura-propia');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await settle();

    expect(emissions, isEmpty);

    // Pasado el silencio, un guardado del usuario vuelve a avisar.
    target.writeAsStringSync('guardado-del-usuario');
    await settle();
    expect(emissions, hasLength(1));
  });
}
