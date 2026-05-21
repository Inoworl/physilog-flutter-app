import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('final release gate checklist covers required approval evidence', () {
    final file = File('docs/final_release_gate.md');

    expect(file.existsSync(), isTrue);
    final markdown = file.readAsStringSync();

    for (final requiredText in [
      'flutter analyze',
      'flutter test',
      'iOS dev',
      'iOS prod',
      'Android dev',
      'Android prod',
      'TestFlight',
      '内部テスト',
      'SHA-256',
      'Firebase',
      'Bundle ID',
      'Package ID',
      '表示名',
      'アイコン',
      'ストア文案',
      'スクリーンショット',
      '法務URL',
      'ポリシー申告',
      '人間の明示承認',
      'staged rollout',
    ]) {
      expect(markdown, contains(requiredText));
    }
  });
}
