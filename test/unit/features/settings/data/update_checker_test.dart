import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/features/settings/data/update_checker.dart';

void main() {
  group('UpdateChecker version comparisons', () {
    test('isNewerVersion returns true when latest is greater than current', () {
      expect(
        UpdateChecker.isNewerVersion(current: '1.6.0', latest: '1.7.0'),
        isTrue,
      );
      expect(
        UpdateChecker.isNewerVersion(current: '1.6.0', latest: '2.0.0'),
        isTrue,
      );
      expect(
        UpdateChecker.isNewerVersion(current: '1.6.0', latest: '1.6.1'),
        isTrue,
      );
    });

    test('isNewerVersion returns false when latest is equal or older', () {
      expect(
        UpdateChecker.isNewerVersion(current: '1.6.0', latest: '1.6.0'),
        isFalse,
      );
      expect(
        UpdateChecker.isNewerVersion(current: '1.6.0', latest: '1.5.0'),
        isFalse,
      );
      expect(
        UpdateChecker.isNewerVersion(current: '1.6.1', latest: '1.6.0'),
        isFalse,
      );
      expect(
        UpdateChecker.isNewerVersion(current: '2.0.0', latest: '1.9.9'),
        isFalse,
      );
    });

    test('parseVersion handles standard and build numbers correctly', () {
      expect(UpdateChecker.parseVersion('1.6.0'), <int>[1, 6, 0]);
      expect(UpdateChecker.parseVersion('1.6.0+7'), <int>[1, 6, 0]);
      expect(UpdateChecker.parseVersion('2.1'), <int>[2, 1, 0]);
      expect(UpdateChecker.parseVersion('invalid'), <int>[0, 0, 0]);
    });
  });

  group('UpdateChecker.selectInstallerUrl', () {
    const goodUrl =
        'https://github.com/Juanes3333/forkumentos/releases/download/'
        'v1.9.0/ForkumentosSetup_v1.9.0.exe';

    List<Object?> assets(Map<String, String> byName) => <Object?>[
      for (final entry in byName.entries)
        <String, Object?>{
          'name': entry.key,
          'browser_download_url': entry.value,
        },
    ];

    test('elige el asset con el nombre exacto, no el primer .exe', () {
      final url = UpdateChecker.selectInstallerUrl(
        assets: assets(<String, String>{
          'otra-herramienta.exe': 'https://example.com/otra.exe',
          'ForkumentosSetup_v1.9.0.exe': goodUrl,
        }),
        version: '1.9.0',
      );

      expect(url, goodUrl);
    });

    test('el tag con o sin "v" y el build number dan el mismo nombre', () {
      expect(
        UpdateChecker.installerAssetName('1.9.0'),
        'ForkumentosSetup_v1.9.0.exe',
      );
      expect(
        UpdateChecker.installerAssetName('1.9.0+10'),
        'ForkumentosSetup_v1.9.0.exe',
      );
    });

    test('sin asset con el nombre exacto devuelve null', () {
      expect(
        UpdateChecker.selectInstallerUrl(
          assets: assets(<String, String>{
            'ForkumentosSetup_v1.8.0.exe': 'https://example.com/old.exe',
            'setup.exe': 'https://example.com/setup.exe',
          }),
          version: '1.9.0',
        ),
        isNull,
      );
      expect(
        UpdateChecker.selectInstallerUrl(assets: null, version: '1.9.0'),
        isNull,
      );
    });

    test('rechaza una URL que no es https', () {
      expect(
        UpdateChecker.selectInstallerUrl(
          assets: assets(<String, String>{
            'ForkumentosSetup_v1.9.0.exe': 'http://example.com/setup.exe',
          }),
          version: '1.9.0',
        ),
        isNull,
      );
    });
  });

  group('UpdateChecker.downloadInstaller', () {
    late HttpServer server;
    late Directory tempDir;
    late int statusCode;
    late bool stallAfterFirstChunk;
    late bool sendTruncated;
    final payload = List<int>.generate(10000, (i) => i % 256);

    setUp(() async {
      statusCode = HttpStatus.ok;
      stallAfterFirstChunk = false;
      sendTruncated = false;
      tempDir = await Directory.systemTemp.createTemp('update_checker_test_');
      server = (await HttpServer.bind(InternetAddress.loopbackIPv4, 0))
        ..listen((request) async {
          final response = request.response..statusCode = statusCode;
          if (statusCode == HttpStatus.ok) {
            response.contentLength = payload.length;
            if (stallAfterFirstChunk) {
              response.add(payload.sublist(0, 2500));
              await response.flush();
              // Se queda sin enviar más datos hasta que el test cierra.
              await Completer<void>().future;
            }
            if (sendTruncated) {
              response.add(payload.sublist(0, 2500));
              try {
                // Cerrar con menos bytes que el contentLength corta la
                // conexión a medias.
                await response.close();
              } on Object {
                // Error esperado del servidor por el contentLength.
              }
              return;
            }
            // Varios chunks para que el progreso se reporte más de una vez.
            for (var i = 0; i < payload.length; i += 2500) {
              response.add(payload.sublist(i, i + 2500));
              await response.flush();
            }
          }
          await response.close();
        });
    });

    tearDown(() async {
      await server.close(force: true);
      await tempDir.delete(recursive: true);
    });

    String url() => 'http://127.0.0.1:${server.port}/setup.exe';

    test('escribe el archivo y reporta progreso hasta el total', () async {
      final received = <int>[];
      final totals = <int>{};

      final file = await UpdateChecker.downloadInstaller(
        downloadUrl: url(),
        version: '1.9.0',
        targetDirectory: tempDir,
        onProgress: (bytes, total) {
          received.add(bytes);
          totals.add(total);
        },
      );

      expect(file.path, endsWith('ForkumentosSetup_v1.9.0.exe'));
      expect(file.readAsBytesSync(), payload);
      expect(received, isNotEmpty);
      expect(received.last, payload.length);
      expect(received, orderedEquals([...received]..sort()));
      expect(totals, <int>{payload.length});
    });

    test('lanza HttpException si la respuesta no es 200', () async {
      statusCode = HttpStatus.notFound;

      await expectLater(
        UpdateChecker.downloadInstaller(
          downloadUrl: url(),
          version: '1.9.0',
          targetDirectory: tempDir,
        ),
        throwsA(isA<HttpException>()),
      );
      expect(tempDir.listSync(), isEmpty);
    });

    test(
      'un flujo que se detiene lanza TimeoutException y no deja nada',
      () async {
        stallAfterFirstChunk = true;

        await expectLater(
          UpdateChecker.downloadInstaller(
            downloadUrl: url(),
            version: '1.9.0',
            targetDirectory: tempDir,
            idleTimeout: const Duration(milliseconds: 300),
          ),
          throwsA(isA<TimeoutException>()),
        );
        expect(tempDir.listSync(), isEmpty);
      },
    );

    test(
      'una descarga incompleta falla y no deja el archivo parcial',
      () async {
        sendTruncated = true;

        await expectLater(
          UpdateChecker.downloadInstaller(
            downloadUrl: url(),
            version: '1.9.0',
            targetDirectory: tempDir,
            idleTimeout: const Duration(seconds: 3),
          ),
          throwsA(isA<Exception>()),
        );
        expect(tempDir.listSync(), isEmpty);
      },
    );
  });
}
