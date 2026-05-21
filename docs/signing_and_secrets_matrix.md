# Signing And Secrets Matrix

Issue: #26

This matrix records required release signing assets and GitHub secret names.
Never paste secret values, private keys, keystores, provisioning profiles, p12
files, p8 files, or service account JSON into this document.

## Android

Release signing is configured in `android/app/build.gradle.kts`.

The release signing config accepts CI environment variables first and falls back
to local `android/key.properties`.

Expected GitHub secrets:

- `ANDROID_UPLOAD_KEYSTORE_JKS_BASE64`
- `ANDROID_UPLOAD_KEYSTORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`
- `GOOGLE_PLAY_CONSOLE_API_SERVICE_ACCOUNT_KEY_JSON_BASE64`

Expected CI restore files:

- `android/upload-keystore.jks`
- `android/key.properties`

`android/key.properties` should contain:

```properties
storePassword=<secret>
keyPassword=<secret>
keyAlias=<secret>
storeFile=../upload-keystore.jks
```

## iOS

Expected shared App Store Connect secrets:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_API_KEY_BASE64`

Expected signing secrets:

- `IOS_CERTIFICATES_P12_BASE64`
- `IOS_CERTIFICATES_P12_PASSWORD`
- `DEVELOPMENT_TEAM_ID`
- `DEV_PROVISIONING_PROFILE_BASE64`
- `DEV_PROVISIONING_PROFILE_SPECIFIER`
- `PROD_PROVISIONING_PROFILE_BASE64`
- `PROD_PROVISIONING_PROFILE_SPECIFIER`

## GitHub Environments

- `dev`: exists and has current iOS dev signing secrets.
- `prod`: must be created before prod iOS or prod Android CI can run.

## Validation Gate

- [ ] Android release signing does not use the debug signing config
- [ ] Android upload key is available outside the repository
- [ ] iOS dev provisioning profile matches `com.physilog.physiLog.dev`
- [ ] iOS prod provisioning profile matches `com.physilog.physiLog`
- [ ] GitHub secrets exist in the intended environment
- [ ] No private signing asset is committed
