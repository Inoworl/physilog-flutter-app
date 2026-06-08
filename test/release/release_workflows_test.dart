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

    test(
      'Android workflowは対象flavorをビルドしてFirebase App Distributionへアップロードする',
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
          packageNameSecret: 'DEV_ANDROID_PACKAGE_NAME',
          firebaseProjectSecret: 'DEV_FIREBASE_PROJECT_ID',
          firebaseAppIdSecret: 'DEV_FIREBASE_ANDROID_APP_ID',
          firebaseServiceAccountSecret:
              'DEV_FIREBASE_SERVICE_ACCOUNT_KEY_BASE64',
          uploadsToPlayStoreInternal: true,
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
          uploadsToPlayStoreInternal: true,
        );
      },
    );

    test('初回リリースversionは1.0.0を使う', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains('version: 1.0.0+1'));
    });

    test('本番iOS workflowは本番Secretsとfastlane prodを使う', () {
      final yaml =
          File('.github/workflows/deploy_prod_ios.yml').readAsStringSync();

      expect(yaml, contains('environment: prod'));
      expect(yaml, contains('PROD_GOOGLESERVICE_INFO_PLIST_BASE64'));
      expect(yaml, contains('PROD_FIREBASE_OPTIONS_DART_BASE64'));
      expect(yaml, contains('PROD_DART_DEFINE_JSON_BASE64'));
      expect(
        yaml,
        contains('ios/Runner/Firebase/Prod/GoogleService-Info.plist'),
      );
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

    test('リリースビルドはFirestore保存モードを有効にする', () {
      final devAndroid =
          File('.github/workflows/deploy_dev_android.yml').readAsStringSync();
      final prodAndroid =
          File('.github/workflows/deploy_prod_android.yml').readAsStringSync();
      final devIos =
          File('.github/workflows/deploy_dev_ios.yml').readAsStringSync();
      final prodIos =
          File('.github/workflows/deploy_prod_ios.yml').readAsStringSync();
      final fastfile = File('ios/fastlane/Fastfile').readAsStringSync();

      expect(
        devAndroid,
        contains('--dart-define-from-file=dart_define/dev_dart_define.json'),
      );
      expect(
        prodAndroid,
        contains('--dart-define-from-file=dart_define/prod_dart_define.json'),
      );
      expect(devAndroid, contains('DEV_DART_DEFINE_JSON_BASE64'));
      expect(prodAndroid, contains('PROD_DART_DEFINE_JSON_BASE64'));
      expect(devIos, contains('DEV_DART_DEFINE_JSON_BASE64'));
      expect(prodIos, contains('PROD_DART_DEFINE_JSON_BASE64'));
      expect(
        fastfile,
        contains(
          'flutter_dart_defines_from_file("../dart_define/dev_dart_define.json"',
        ),
      );
      expect(
        fastfile,
        contains(
          'flutter_dart_defines_from_file("../dart_define/prod_dart_define.json"',
        ),
      );
      expect(fastfile, contains('"DATA_STORE_MODE" => "firestore"'));
    });

    test('Android releaseビルドはdebug署名ではなくupload key署名を使う', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('create("release")'));
      expect(gradle, contains('ANDROID_UPLOAD_KEYSTORE_PATH'));
      expect(gradle, contains('ANDROID_UPLOAD_KEYSTORE_PASSWORD'));
      expect(gradle, contains('ANDROID_UPLOAD_KEY_ALIAS'));
      expect(gradle, contains('ANDROID_UPLOAD_KEY_PASSWORD'));
      expect(
        gradle,
        contains('signingConfig = signingConfigs.getByName("release")'),
      );
      expect(
        gradle,
        isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
      );
    });

    test('dev Android workflowはupload keyを復元してAABとAPKを署名する', () {
      final yaml =
          File('.github/workflows/deploy_dev_android.yml').readAsStringSync();

      expect(yaml, contains('Validate Android signing secrets'));
      expect(yaml, contains('Restore Android signing keystore'));
      expect(yaml, contains('Create Android key.properties'));
      expect(yaml, contains('ANDROID_UPLOAD_KEYSTORE_JKS_BASE64'));
      expect(yaml, contains('ANDROID_UPLOAD_KEYSTORE_PASSWORD'));
      expect(yaml, contains('ANDROID_UPLOAD_KEY_ALIAS'));
      expect(yaml, contains('ANDROID_UPLOAD_KEY_PASSWORD'));
      expect(yaml, contains('ANDROID_UPLOAD_KEYSTORE_PATH'));
      expect(yaml, contains('android/upload-keystore.jks'));
      expect(yaml, contains('storeFile=../upload-keystore.jks'));
    });

    test('PRテンプレートはmerge前の実機確認を要求する', () {
      final template = File('.github/PULL_REQUEST_TEMPLATE.md');

      expect(template.existsSync(), isTrue);

      final markdown = template.readAsStringSync();
      expect(markdown, contains('実機確認'));
      expect(markdown, contains('Firebase App Distribution'));
      expect(markdown, contains('Play Store Internal'));
      expect(markdown, contains('選手一覧'));
      expect(markdown, contains('Firestore index'));
    });

    test('GitHub Pages workflowは使わない', () {
      expect(File('.github/workflows/deploy_pages.yml').existsSync(), isFalse);
    });

    test('Firebase Hosting workflowはdevを自動、prodを手動でデプロイする', () {
      final dev = File('.github/workflows/deploy_dev_hosting.yml');
      final prod = File('.github/workflows/deploy_prod_hosting.yml');

      expect(dev.existsSync(), isTrue);
      expect(prod.existsSync(), isTrue);

      final devYaml = dev.readAsStringSync();
      expect(devYaml, contains('name: "[Release] Dev Hosting"'));
      expect(devYaml, contains('branches: [dev]'));
      expect(devYaml, contains('docs/pages/**'));
      expect(devYaml, contains('firebase.json'));
      expect(devYaml, contains('DEV_FIREBASE_SERVICE_ACCOUNT_KEY_BASE64'));
      expect(devYaml, contains('DEV_FIREBASE_PROJECT_ID'));
      expect(devYaml, contains('firebase deploy --only hosting'));

      final prodYaml = prod.readAsStringSync();
      expect(prodYaml, contains('name: "[Release] Prod Hosting"'));
      expect(prodYaml, contains('workflow_dispatch:'));
      expect(prodYaml, isNot(contains('branches: [main]')));
      expect(prodYaml, contains('PROD_FIREBASE_SERVICE_ACCOUNT_KEY_BASE64'));
      expect(prodYaml, contains('PROD_FIREBASE_PROJECT_ID'));
      expect(prodYaml, contains('firebase deploy --only hosting'));
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
  required bool uploadsToPlayStoreInternal,
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
  expect(
    yaml,
    contains('${environment.toUpperCase()}_GOOGLE_SERVICES_JSON_BASE64'),
  );
  expect(
    yaml,
    contains('${environment.toUpperCase()}_FIREBASE_OPTIONS_DART_BASE64'),
  );
  expect(
    yaml,
    contains('${environment.toUpperCase()}_DART_DEFINE_JSON_BASE64'),
  );
  expect(yaml, contains(packageNameSecret));
  expect(yaml, contains(firebaseProjectSecret));
  expect(yaml, contains(firebaseAppIdSecret));
  expect(yaml, contains(firebaseServiceAccountSecret));
  expect(yaml, isNot(contains('firebase apps:sdkconfig ANDROID')));
  expect(yaml, contains('firebase appdistribution:distribute'));
  expect(yaml, isNot(contains('upload_to_play')));
  expect(yaml, isNot(contains('inputs.upload_to_play')));
  if (uploadsToPlayStoreInternal) {
    expect(yaml, contains('r0adkll/upload-google-play@v1'));
    expect(
      yaml,
      contains('GOOGLE_PLAY_CONSOLE_API_SERVICE_ACCOUNT_KEY_JSON_BASE64'),
    );
    expect(
      yaml,
      contains(
        'GOOGLE_PLAY_CONSOLE_API_SERVICE_ACCOUNT_KEY_JSON_BASE64: '
        '\${{ secrets.GOOGLE_PLAY_CONSOLE_API_SERVICE_ACCOUNT_KEY_JSON_BASE64 }}',
      ),
    );
    expect(
      yaml,
      contains(
        'if [ -z "\$GOOGLE_PLAY_CONSOLE_API_SERVICE_ACCOUNT_KEY_JSON_BASE64" ]; then',
      ),
    );
    expect(
      yaml,
      contains('Google Play Console API Service Account Key is required'),
    );
    expect(
      yaml,
      contains(
        'releaseFiles: build/app/outputs/bundle/${flavor}Release/app-$flavor-release.aab',
      ),
    );
    expect(yaml, contains('track: internal'));
    expect(yaml, contains('status: completed'));
  } else {
    expect(yaml, isNot(contains('r0adkll/upload-google-play@v1')));
    expect(yaml, isNot(contains('track: internal')));
    expect(yaml, isNot(contains('status: completed')));
  }
}
