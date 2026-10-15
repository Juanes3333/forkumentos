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

  group('UpdateChecker.downloadInstaller', () {
    late HttpServer server;
    late Directory tempDir;
    late int statusCode;
    final payload = List<int>.generate(10000, (i) => i % 256);

    setUp(() async {
      statusCode = HttpStatus.ok;
      tempDir = await Directory.systemTemp.createTemp('update_checker_test_');
      server = (await HttpServer.bind(InternetAddress.loopbackIPv4, 0))
        ..listen((request) async {
          final response = request.response..statusCode = statusCode;
          if (statusCode == HttpStatus.ok) {
            response.contentLength = payload.length;
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
  });
}
