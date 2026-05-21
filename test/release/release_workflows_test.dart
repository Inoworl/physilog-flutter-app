import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('リリースworkflow', () {
    test('すべてのリリースworkflowを手動実行できる', () {
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
          reason: '${entry.key} workflowが必要です',
        );

        final yaml = entry.value.readAsStringSync();
        expect(yaml, contains('workflow_dispatch:'));
        expect(yaml, contains('uses: ./.github/actions/setup'));
        expect(yaml, contains('actions/upload-artifact@v4'));
      }
    });

    test('workflow表示名はiOSとAndroidでRelease表記に揃える', () {
      final workflowNames = {
        '.github/workflows/deploy_dev_ios.yml': '[Release] Dev iOS',
        '.github/workflows/deploy_dev_android.yml': '[Release] Dev Android',
        '.github/workflows/deploy_prod_ios.yml': '[Release] Prod iOS',
        '.github/workflows/deploy_prod_android.yml': '[Release] Prod Android',
      };

      for (final entry in workflowNames.entries) {
        final yaml = File(entry.key).readAsStringSync();
        expect(yaml, contains('name: "${entry.value}"'));
      }
    });

    test('Android workflowは対象flavorをビルドしてFirebase App Distributionへアップロードする', () {
      final dev =
          File('.github/workflows/deploy_dev_android.yml').readAsStringSync();
      final prod =
          File('.github/workflows/deploy_prod_android.yml').readAsStringSync();

      _expectAndroidWorkflow(
        yaml: dev,
        environment: 'dev',
        flavor: 'dev',
        firebaseConfigPath: 'android/app/src/dev/google-services.json',
        packageNameSecret: 'DEV_ANDROID_PACKAGE_NAME',
        firebaseProjectSecret: 'DEV_FIREBASE_PROJECT_ID',
        firebaseAppIdSecret: 'DEV_FIREBASE_ANDROID_APP_ID',
        firebaseServiceAccountSecret: 'DEV_FIREBASE_SERVICE_ACCOUNT_KEY_BASE64',
      );
      _expectAndroidWorkflow(
        yaml: prod,
        environment: 'prod',
        flavor: 'prod',
        firebaseConfigPath: 'android/app/src/prod/google-services.json',
        packageNameSecret: 'PROD_ANDROID_PACKAGE_NAME',
        firebaseProjectSecret: 'PROD_FIREBASE_PROJECT_ID',
        firebaseAppIdSecret: 'PROD_FIREBASE_ANDROID_APP_ID',
        firebaseServiceAccountSecret:
            'PROD_FIREBASE_SERVICE_ACCOUNT_KEY_BASE64',
      );
    });

    test('本番iOS workflowは本番Secretsとfastlane prodを使う', () {
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

    test('Fastfileに本番TestFlight laneがある', () {
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
  required String packageNameSecret,
  required String firebaseProjectSecret,
  required String firebaseAppIdSecret,
  required String firebaseServiceAccountSecret,
}) {
  expect(yaml, contains('environment: $environment'));
  expect(yaml, contains('--flavor $flavor'));
  expect(
    yaml,
    contains('--target-platform android-arm,android-arm64,android-x64'),
  );
  expect(
    yaml,
    contains(
      '--build-number="\${{ steps.calculate_build_number.outputs.build_number }}"',
    ),
  );
  expect(yaml, contains(firebaseConfigPath));
  expect(yaml, contains(packageNameSecret));
  expect(yaml, contains(firebaseProjectSecret));
  expect(yaml, contains(firebaseAppIdSecret));
  expect(yaml, contains(firebaseServiceAccountSecret));
  expect(yaml, contains('firebase apps:sdkconfig ANDROID'));
  expect(yaml, contains('firebase appdistribution:distribute'));
  expect(yaml, isNot(contains('upload_to_play')));
  expect(yaml, isNot(contains('inputs.upload_to_play')));
  expect(yaml, isNot(contains('r0adkll/upload-google-play@v1')));
  expect(yaml, isNot(contains('track: internal')));
  expect(yaml, isNot(contains('status: completed')));
}
