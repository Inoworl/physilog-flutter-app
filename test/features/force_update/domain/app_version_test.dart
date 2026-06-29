import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/force_update/domain/app_version.dart';

void main() {
  group('AppVersion', () {
    test('現在バージョンが最低必須バージョン未満の場合はtrueを返す', () {
      expect(
        AppVersion.isCurrentVersionLessThanMinRequired(
          currentVersion: '1.2.9',
          minRequiredVersion: '1.3.0',
        ),
        isTrue,
      );
    });

    test('二桁のminorとpatchを数値として比較する', () {
      expect(
        AppVersion.isCurrentVersionLessThanMinRequired(
          currentVersion: '1.10.0',
          minRequiredVersion: '1.2.0',
        ),
        isFalse,
      );

      expect(
        AppVersion.isCurrentVersionLessThanMinRequired(
          currentVersion: '1.0.10',
          minRequiredVersion: '1.0.2',
        ),
        isFalse,
      );
    });

    test('ビルド番号とプレリリース表記は除外して比較する', () {
      expect(
        AppVersion.isCurrentVersionLessThanMinRequired(
          currentVersion: '1.2.3+4',
          minRequiredVersion: '1.2.3',
        ),
        isFalse,
      );

      expect(
        AppVersion.isCurrentVersionLessThanMinRequired(
          currentVersion: '1.2.3-beta+4',
          minRequiredVersion: '1.2.3',
        ),
        isFalse,
      );
    });

    test('最低必須バージョンが空または不正な場合はfalseを返す', () {
      expect(
        AppVersion.isCurrentVersionLessThanMinRequired(
          currentVersion: '1.2.3',
          minRequiredVersion: '',
        ),
        isFalse,
      );

      expect(
        AppVersion.isCurrentVersionLessThanMinRequired(
          currentVersion: '1.2.3',
          minRequiredVersion: 'not-a-version',
        ),
        isFalse,
      );
    });
  });
}
