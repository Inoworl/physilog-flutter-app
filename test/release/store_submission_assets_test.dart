import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store submission asset ledger covers required release fields', () {
    final file = File('docs/store_submission_assets.md');

    expect(file.existsSync(), isTrue);
    final markdown = file.readAsStringSync();

    for (final requiredText in [
      'App Store Connect',
      'Google Play Console',
      'プロモーション用テキスト',
      '短い説明',
      '詳しい説明',
      'リリースノート',
      'プライバシーポリシーURL',
      '利用規約URL',
      'サポートURL',
      'スクリーンショット',
      '本番個人データ',
      '未実装機能',
      '人間判断',
    ]) {
      expect(markdown, contains(requiredText));
    }
  });
}
