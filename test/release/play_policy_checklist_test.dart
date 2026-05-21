import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play policy checklist covers required declarations', () {
    final file = File('docs/play_policy_checklist.md');

    expect(file.existsSync(), isTrue);
    final markdown = file.readAsStringSync();

    for (final requiredText in [
      'データセーフティ',
      'Firebase Auth',
      'Firestore',
      '動画',
      'カメラ',
      '写真と動画',
      '広告ID',
      '健康アプリ',
      '金融取引',
      '行政アプリ',
      '対象年齢',
      'コンテンツレーティング',
      'クローズドテスト',
      'プライバシーポリシー',
      '人間承認',
    ]) {
      expect(markdown, contains(requiredText));
    }
  });
}
