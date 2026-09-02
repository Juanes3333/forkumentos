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
}
