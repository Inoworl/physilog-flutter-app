import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradleFile = File('android/app/build.gradle.kts');

  test('release builds use the release signing config', () {
    final content = gradleFile.readAsStringSync();

    expect(content, contains('create("release")'));
    expect(content, contains('signingConfig = signingConfigs.getByName("release")'));
    expect(content, isNot(contains('signingConfig = signingConfigs.getByName("debug")')));
  });

  test('release signing can be supplied from CI environment variables', () {
    final content = gradleFile.readAsStringSync();

    expect(content, contains('ANDROID_UPLOAD_KEYSTORE_PATH'));
    expect(content, contains('ANDROID_UPLOAD_KEYSTORE_PASSWORD'));
    expect(content, contains('ANDROID_UPLOAD_KEY_ALIAS'));
    expect(content, contains('ANDROID_UPLOAD_KEY_PASSWORD'));
  });

  test('release signing can fall back to local key.properties', () {
    final content = gradleFile.readAsStringSync();

    expect(content, contains('key.properties'));
    expect(content, contains('storePassword'));
    expect(content, contains('keyPassword'));
    expect(content, contains('keyAlias'));
    expect(content, contains('storeFile'));
  });
}
