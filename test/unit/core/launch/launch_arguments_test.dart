import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forkumentos/core/launch/launch_arguments.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'forkumentos_launch_args_',
    );
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('resolveLaunchProjectPath returns first existing .fork', () async {
    final fork = File(p.join(tempDirectory.path, 'demo.fork'));
    await fork.writeAsString('{}');
    final missing = p.join(tempDirectory.path, 'missing.fork');

    expect(
      resolveLaunchProjectPath(<String>[missing, fork.path, '--new']),
      fork.path,
    );
  });

  test('resolveLaunchProjectPath is case-insensitive on extension', () async {
    final fork = File(p.join(tempDirectory.path, 'Demo.FORK'));
    await fork.writeAsString('{}');

    expect(resolveLaunchProjectPath(<String>[fork.path]), fork.path);
  });

  test('resolveLaunchProjectPath ignores non-.fork args', () {
    expect(
      resolveLaunchProjectPath(<String>['--new', r'C:\temp\file.txt']),
      isNull,
    );
  });

  test('wantsNewProject requires exact --new', () {
    expect(wantsNewProject(const <String>['--new']), isTrue);
    expect(wantsNewProject(const <String>['--new-project']), isFalse);
    expect(wantsNewProject(const <String>['file.fork']), isFalse);
  });
}
