# Mobile release secrets

PhysiLogのAndroid/iOS dev/prodリリースは、Firebase設定・Dart define・署名情報をGitHub Secretsから復元してビルドします。設定ファイル本体はリポジトリにコミットしません。

## Backup location

ローカルで取得した設定ファイルは、次のGoogle Drive配下にバックアップします。

```text
/Users/keisukeshimizu/Library/CloudStorage/GoogleDrive-keisukeshimizu.inoworl@gmail.com/マイドライブ/Obsidian/my-work-vault/projects/PhysiLog/release-assets/
```

今回の初期バックアップは `latest-backup-path.txt` が指す `backup-YYYYmmdd-HHMMSS/` 配下に保存しています。

## Required GitHub Secrets

共通:

- `APP_FIREBASE_OPTIONS_DART_BASE64` as a repository secret for PR CI and release builds
- `DEV_FIREBASE_OPTIONS_DART_BASE64` as a repository secret for PR CI and release builds
- `PROD_FIREBASE_OPTIONS_DART_BASE64` as a repository secret for PR CI and release builds
- `ANDROID_UPLOAD_KEYSTORE_JKS_BASE64`
- `ANDROID_UPLOAD_KEYSTORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`
- `GOOGLE_PLAY_CONSOLE_API_SERVICE_ACCOUNT_KEY_JSON_BASE64`
- `IOS_CERTIFICATES_P12_BASE64`
- `IOS_CERTIFICATES_P12_PASSWORD`
- `DEVELOPMENT_TEAM_ID`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_API_KEY_BASE64`

dev:

- `DEV_GOOGLE_SERVICES_JSON_BASE64`
- `DEV_GOOGLESERVICE_INFO_PLIST_BASE64`
- `DEV_FIREBASE_OPTIONS_DART_BASE64`
- `DEV_DART_DEFINE_JSON_BASE64`
- `DEV_FIREBASE_SERVICE_ACCOUNT_KEY_BASE64`
- `DEV_FIREBASE_PROJECT_ID`
- `DEV_FIREBASE_ANDROID_APP_ID`
- `DEV_ANDROID_PACKAGE_NAME`
- `DEV_PROVISIONING_PROFILE_BASE64`
- `DEV_PROVISIONING_PROFILE_SPECIFIER`

prod:

- `PROD_GOOGLE_SERVICES_JSON_BASE64`
- `PROD_GOOGLESERVICE_INFO_PLIST_BASE64`
- `PROD_FIREBASE_OPTIONS_DART_BASE64`
- `PROD_DART_DEFINE_JSON_BASE64`
- `PROD_FIREBASE_SERVICE_ACCOUNT_KEY_BASE64`
- `PROD_FIREBASE_PROJECT_ID`
- `PROD_FIREBASE_ANDROID_APP_ID`
- `PROD_ANDROID_PACKAGE_NAME`
- `PROD_PROVISIONING_PROFILE_BASE64`
- `PROD_PROVISIONING_PROFILE_SPECIFIER`

TestFlight外部テスター配布をdevで使う場合:

- `DEV_TESTFLIGHT_EXTERNAL_GROUPS`
- `DEV_TESTFLIGHT_NOTIFY_EXTERNAL_TESTERS`
- `DEV_TESTFLIGHT_BETA_APP_DESCRIPTION`
- `DEV_TESTFLIGHT_WHATS_NEW_JA`
- `DEV_TESTFLIGHT_FEEDBACK_EMAIL`
- `DEV_TESTFLIGHT_CONTACT_FIRST_NAME`
- `DEV_TESTFLIGHT_CONTACT_LAST_NAME`
- `DEV_TESTFLIGHT_CONTACT_EMAIL`
- `DEV_TESTFLIGHT_CONTACT_PHONE_E164`
- `DEV_TESTFLIGHT_EXTERNAL_TESTER_EMAIL`
- `DEV_TESTFLIGHT_EXTERNAL_TESTER_FIRST_NAME`
- `DEV_TESTFLIGHT_EXTERNAL_TESTER_LAST_NAME`

prod TestFlight release notes:

- `PROD_TESTFLIGHT_WHATS_NEW_JA`

## Secret registration examples

値をターミナルやチャットに表示しないため、ファイルをbase64化してそのまま `gh secret set` に渡します。

```sh
base64 -i android/app/src/dev/google-services.json | gh secret set DEV_GOOGLE_SERVICES_JSON_BASE64
base64 -i android/app/src/prod/google-services.json | gh secret set PROD_GOOGLE_SERVICES_JSON_BASE64
base64 -i ios/Runner/Firebase/Dev/GoogleService-Info.plist | gh secret set DEV_GOOGLESERVICE_INFO_PLIST_BASE64
base64 -i ios/Runner/Firebase/Prod/GoogleService-Info.plist | gh secret set PROD_GOOGLESERVICE_INFO_PLIST_BASE64
base64 -i lib/firebase_options.dart | gh secret set APP_FIREBASE_OPTIONS_DART_BASE64
base64 -i lib/firebase_options_dev.dart | gh secret set DEV_FIREBASE_OPTIONS_DART_BASE64
base64 -i lib/firebase_options_prod.dart | gh secret set PROD_FIREBASE_OPTIONS_DART_BASE64
base64 -i dart_define/dev_dart_define.json | gh secret set DEV_DART_DEFINE_JSON_BASE64
base64 -i dart_define/prod_dart_define.json | gh secret set PROD_DART_DEFINE_JSON_BASE64
```

署名・APIキーも同じ方式で登録します。

```sh
base64 -i android/upload-keystore.jks | gh secret set ANDROID_UPLOAD_KEYSTORE_JKS_BASE64
base64 -i ios/certificates.p12 | gh secret set IOS_CERTIFICATES_P12_BASE64
base64 -i ios/profile-dev.mobileprovision | gh secret set DEV_PROVISIONING_PROFILE_BASE64
base64 -i ios/profile-prod.mobileprovision | gh secret set PROD_PROVISIONING_PROFILE_BASE64
base64 -i AuthKey.p8 | gh secret set ASC_API_KEY_BASE64
base64 -i google-play-service-account.json | gh secret set GOOGLE_PLAY_CONSOLE_API_SERVICE_ACCOUNT_KEY_JSON_BASE64
```

Secret値はファイルから直接渡し、`echo` やPythonで本文を読み上げないでください。
