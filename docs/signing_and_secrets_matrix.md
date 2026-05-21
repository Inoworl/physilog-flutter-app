# 署名とSecretsの一覧

対象Issue: #26

この一覧は、リリース署名に必要な資材と GitHub Secrets 名を記録するためのものです。
Secret の値、秘密鍵、keystore、Provisioning Profile、p12 ファイル、p8 ファイル、サービスアカウント JSON は、この文書に貼り付けないでください。

## Android

リリース署名は `android/app/build.gradle.kts` で設定します。

リリース署名設定は、まず CI の環境変数を読み、未指定の場合はローカルの `android/key.properties` にフォールバックします。

必要な GitHub Secrets:

- `ANDROID_UPLOAD_KEYSTORE_JKS_BASE64`
- `ANDROID_UPLOAD_KEYSTORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`
- `GOOGLE_PLAY_CONSOLE_API_SERVICE_ACCOUNT_KEY_JSON_BASE64`

CI で復元するファイル:

- `android/upload-keystore.jks`
- `android/key.properties`

`android/key.properties` には以下を設定します。

```properties
storePassword=<secret>
keyPassword=<secret>
keyAlias=<secret>
storeFile=../upload-keystore.jks
```

## iOS

App Store Connect 共通で必要な Secrets:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_API_KEY_BASE64`

署名に必要な Secrets:

- `IOS_CERTIFICATES_P12_BASE64`
- `IOS_CERTIFICATES_P12_PASSWORD`
- `DEVELOPMENT_TEAM_ID`
- `DEV_PROVISIONING_PROFILE_BASE64`
- `DEV_PROVISIONING_PROFILE_SPECIFIER`
- `PROD_PROVISIONING_PROFILE_BASE64`
- `PROD_PROVISIONING_PROFILE_SPECIFIER`

## GitHub Environment設定

- `dev`: 作成済み。現在の iOS dev 署名 Secrets が登録されています。
- `prod`: prod iOS または prod Android CI を実行する前に作成が必要です。

## 検証ゲート

- [ ] Android リリース署名が debug signing config を使っていない
- [ ] Android upload key がリポジトリ外で管理されている
- [ ] iOS dev Provisioning Profile が `com.physilog.physiLog.dev` と一致している
- [ ] iOS prod Provisioning Profile が `com.physilog.physiLog` と一致している
- [ ] 必要な GitHub Secrets が対象 Environment に存在する
- [ ] 秘密の署名資材がコミットされていない
