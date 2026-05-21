# Android Dev Play Console Setup

Issue: #23

This runbook defines the first Google Play Console setup for the Android dev
application. The console creation step is manual; do not create or submit Play
Console records without explicit human approval.

## Confirmed Local Configuration

- App display name: `PhysiLog Dev`
- Android package name: `com.physilog.physi_log.dev`
- Base package name: `com.physilog.physi_log`
- Gradle flavor: `dev`
- Flavor dimension: `env`
- App label placeholder: `PhysiLog Dev`
- Existing resource directory: `android/app/src/dev`
- Current gap: release builds still use debug signing until signing is fixed

## Play Console Creation Parameters

Use this baseline when creating the dev app:

- App name: `PhysiLog Dev`
- Default language: Japanese
- App or game: app
- Free or paid: free unless the business model changes
- Package name: `com.physilog.physi_log.dev`
- Managed publishing: enable if available, to avoid accidental release
- Initial track: internal testing

Record the created Play Console app URL in Issue #23.

## Firebase Linkage

Before uploading the first dev Android build:

- [ ] Dev Firebase project is selected
- [ ] Android app `com.physilog.physi_log.dev` exists in that Firebase project
- [ ] `google-services.json` for the dev Android app is stored as a GitHub Secret
- [ ] CI restores it to the dev source set expected by the Gradle build
- [ ] Any Firebase App Distribution app ID is recorded as a secret name only

Do not commit `google-services.json` or Firebase service account JSON.

## Internal Distribution Gate

The first internal build is acceptable only after:

- [ ] Android release signing no longer uses the debug signing config
- [ ] Upload key / keystore secrets are configured
- [ ] Dev AAB is built with `--flavor dev`
- [ ] Build uses `dart_define/dev_dart_define.json` or an equivalent CI-restored file
- [ ] Play App Signing is enabled or its setup choice is documented
- [ ] At least one internal tester can install the dev build

## Expected Local Build Command

After signing and Firebase configuration exist:

```bash
fvm flutter build appbundle --release \
  --flavor dev \
  --dart-define-from-file=dart_define/dev_dart_define.json
```

## Stop Conditions

Stop before upload if any of these are true:

- The package name is `com.physilog.physi_log` instead of the dev package name
- The build is signed with the debug key
- Firebase config points at production
- The Play Console app being edited is not `PhysiLog Dev`
- A policy declaration is required and has not been reviewed by a human
