import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradleFile = File('android/app/build.gradle.kts');

  test('リリースビルドはrelease署名設定を使う', () {
    final content = gradleFile.readAsStringSync();

    expect(content, contains('create("release")'));
    expect(
      content,
      contains('signingConfig = signingConfigs.getByName("release")'),
    );
    expect(
      content,
      isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
    );
  });

  test('リリース署名はCI環境変数から渡せる', () {
    final content = gradleFile.readAsStringSync();

    expect(content, contains('ANDROID_UPLOAD_KEYSTORE_PATH'));
    expect(content, contains('ANDROID_UPLOAD_KEYSTORE_PASSWORD'));
    expect(content, contains('ANDROID_UPLOAD_KEY_ALIAS'));
    expect(content, contains('ANDROID_UPLOAD_KEY_PASSWORD'));
  });

  test('リリース署名はローカルkey.propertiesへフォールバックできる', () {
    final content = gradleFile.readAsStringSync();

    expect(content, contains('key.properties'));
    expect(content, contains('storePassword'));
    expect(content, contains('keyPassword'));
    expect(content, contains('keyAlias'));
    expect(content, contains('storeFile'));
  });
}
