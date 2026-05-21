# Firebase Release Matrix

Issue: #25

This matrix records the non-secret Firebase identifiers and the expected secret
names for dev/prod release builds. Do not paste Firebase config JSON, service
account JSON, plist contents, private keys, or `.env` values into this file.

## Runtime Selection

The app imports `lib/firebase_options.dart`.

That file selects the environment at runtime from:

- `lib/firebase_options_dev.dart` when `FIREBASE_ENV` is not `prod`
- `lib/firebase_options_prod.dart` when `FIREBASE_ENV=prod`

Release builds must pass the matching dart-define file:

- dev: `dart_define/dev_dart_define.json`
- prod: `dart_define/prod_dart_define.json`

## Environment Matrix

| Environment | iOS bundle ID | Android package | Dart define file | Native config secret | Status |
| --- | --- | --- | --- | --- | --- |
| dev | `com.physilog.physiLog.dev` | `com.physilog.physi_log.dev` | `dart_define/dev_dart_define.json` | `DEV_GOOGLESERVICE_INFO_PLIST_BASE64`, `DEV_GOOGLE_SERVICES_JSON_BASE64` | iOS plist secret exists; Android config needs confirmation |
| prod | `com.physilog.physiLog` | `com.physilog.physi_log` | `dart_define/prod_dart_define.json` | `PROD_GOOGLESERVICE_INFO_PLIST_BASE64`, `PROD_GOOGLE_SERVICES_JSON_BASE64` | GitHub `prod` environment needs creation |

## Required Identifiers To Record In Issue #25

Record these values in Issue #25 after confirming them in Firebase Console:

- Dev Firebase project ID
- Dev iOS Firebase app ID
- Dev Android Firebase app ID
- Prod Firebase project ID
- Prod iOS Firebase app ID
- Prod Android Firebase app ID

Only record identifiers. Do not record API keys or downloaded config file
contents in the issue.

## Native Config Restore Strategy

Expected CI restore locations:

- iOS dev/prod: `ios/Runner/GoogleService-Info.plist`
- Android dev: `android/app/src/dev/google-services.json`
- Android prod: `android/app/src/prod/google-services.json`

Current repository state:

- No `GoogleService-Info.plist` is committed under `ios/Runner`.
- No `google-services.json` is committed under `android/app/src`.
- `.github/workflows/deploy_dev_ios.yml` restores the dev iOS plist from
  `DEV_GOOGLESERVICE_INFO_PLIST_BASE64`.

## Validation Gate

Before any store upload:

- [ ] The build uses the intended `FIREBASE_ENV`
- [ ] The selected Firebase app package/bundle ID matches the native target
- [ ] Native config files are restored from secrets during CI
- [ ] The restored files are not committed
- [ ] The dev build cannot read production data
- [ ] The prod build cannot read dev data

## Stop Conditions

Stop release work if any of these are true:

- `FIREBASE_ENV=prod` is used with a dev bundle ID or package name
- `FIREBASE_ENV=dev` is used with a prod bundle ID or package name
- A config file has been committed to the repository
- Firebase Console app IDs are unknown
- GitHub secret names are missing for the target environment
