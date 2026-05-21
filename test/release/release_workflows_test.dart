import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release workflows', () {
    test('all release workflows are available as manual jobs', () {
      final workflows = {
        'dev iOS': File('.github/workflows/deploy_dev_ios.yml'),
        'dev Android': File('.github/workflows/deploy_dev_android.yml'),
        'prod iOS': File('.github/workflows/deploy_prod_ios.yml'),
        'prod Android': File('.github/workflows/deploy_prod_android.yml'),
      };

      for (final entry in workflows.entries) {
        expect(
          entry.value.existsSync(),
          isTrue,
          reason: '${entry.key} workflow is required',
        );

        final yaml = entry.value.readAsStringSync();
        expect(yaml, contains('workflow_dispatch:'));
        expect(yaml, contains('uses: ./.github/actions/setup'));
        expect(yaml, contains('actions/upload-artifact@v4'));
      }
    });

    test(
      'Android workflows build the expected flavors and gate Play upload',
      () {
        final dev =
            File('.github/workflows/deploy_dev_android.yml').readAsStringSync();
        final prod =
            File(
              '.github/workflows/deploy_prod_android.yml',
            ).readAsStringSync();

        _expectAndroidWorkflow(
          yaml: dev,
          environment: 'dev',
          flavor: 'dev',
          firebaseConfigPath: 'android/app/src/dev/google-services.json',
          packageName: 'com.physilog.physi_log.dev',
        );
        _expectAndroidWorkflow(
          yaml: prod,
          environment: 'prod',
          flavor: 'prod',
          firebaseConfigPath: 'android/app/src/prod/google-services.json',
          packageName: 'com.physilog.physi_log',
        );
      },
    );

    test('prod iOS workflow uses prod secrets and fastlane prod', () {
      final yaml =
          File('.github/workflows/deploy_prod_ios.yml').readAsStringSync();

      expect(yaml, contains('environment: prod'));
      expect(yaml, contains('PROD_GOOGLESERVICE_INFO_PLIST_BASE64'));
      expect(yaml, contains('PROD_PROVISIONING_PROFILE_BASE64'));
      expect(yaml, contains('PROD_PROVISIONING_PROFILE_SPECIFIER'));
      expect(yaml, contains('ASC_KEY_ID'));
      expect(yaml, contains('ASC_ISSUER_ID'));
      expect(yaml, contains('ASC_API_KEY_BASE64'));
      expect(yaml, contains('fastlane prod'));
      expect(yaml, contains('ios-prod-ipa-'));
    });

    test('Fastfile has a prod TestFlight lane', () {
      final fastfile = File('ios/fastlane/Fastfile').readAsStringSync();

      expect(fastfile, contains('lane :prod do'));
      expect(fastfile, contains('com.physilog.physiLog"'));
      expect(fastfile, contains('Release-prod'));
      expect(fastfile, contains('PhysiLog-Prod.ipa'));
      expect(fastfile, contains('PROD_PROVISIONING_PROFILE_BASE64'));
      expect(fastfile, contains('PROD_TESTFLIGHT_WHATS_NEW_JA'));
    });
  });
}

void _expectAndroidWorkflow({
  required String yaml,
  required String environment,
  required String flavor,
  required String firebaseConfigPath,
  required String packageName,
}) {
  expect(yaml, contains('environment: $environment'));
  expect(yaml, contains('--flavor $flavor'));
  expect(yaml, contains(firebaseConfigPath));
  expect(yaml, contains(packageName));
  expect(yaml, contains('ANDROID_UPLOAD_KEYSTORE_JKS_BASE64'));
  expect(yaml, contains('ANDROID_UPLOAD_KEYSTORE_PASSWORD'));
  expect(yaml, contains('ANDROID_UPLOAD_KEY_ALIAS'));
  expect(yaml, contains('ANDROID_UPLOAD_KEY_PASSWORD'));
  expect(
    yaml,
    contains('GOOGLE_PLAY_CONSOLE_API_SERVICE_ACCOUNT_KEY_JSON_BASE64'),
  );
  expect(yaml, contains("inputs.upload_to_play == 'true'"));
  expect(yaml, contains('status: draft'));
}
