# Android Prod Play Console Setup

Issue: #24

This runbook defines the first Google Play Console setup for the Android
production application. The app record does not currently exist in Play Console.

## Confirmed Local Configuration

- Production app display name: `PhysiLog`
- Android package name: `com.physilog.physi_log`
- Gradle flavor: `prod`
- Flavor dimension: `env`
- Production label uses the default `PhysiLog`
- Existing resource directory: `android/app/src/prod`
- Current gap: release builds still use debug signing until signing is fixed
- Current gap: GitHub environment `prod` is not available yet

## Play Console Creation Parameters

Use this baseline when creating the production app:

- App name: `PhysiLog`
- Default language: Japanese
- App or game: app
- Free or paid: free unless the business model changes
- Package name: `com.physilog.physi_log`
- Managed publishing: enable if available
- Initial upload track: internal testing
- Production rollout: disabled until the final gate passes

Record the created Play Console app URL in Issue #24.

## Play App Signing

Before the first upload:

- [ ] Decide whether Google Play App Signing manages the app signing key
- [ ] Confirm upload key ownership and storage location
- [ ] Store upload keystore material outside the repository
- [ ] Register only secret names in GitHub or Issue comments
- [ ] Confirm `android/app/build.gradle.kts` uses release signing for release builds

## First Internal Upload Gate

The first production AAB upload is acceptable only after:

- [ ] Play Console app is `PhysiLog`
- [ ] Package name is `com.physilog.physi_log`
- [ ] AAB is built with `--flavor prod`
- [ ] Build uses prod Firebase config and prod dart defines
- [ ] Build is signed with the upload key, not the debug key
- [ ] Store listing draft has no misleading claims
- [ ] Privacy policy URL is available
- [ ] No production rollout is started

## Expected Local Build Command

After signing and Firebase configuration exist:

```bash
fvm flutter build appbundle --release \
  --flavor prod \
  --dart-define-from-file=dart_define/prod_dart_define.json
```

## Stop Conditions

Stop before upload if any of these are true:

- The package name includes `.dev`
- The build uses dev Firebase config
- The build is signed with the debug key
- `prod` GitHub environment and secrets are not configured
- The policy declarations have not been reviewed by a human
- The Play Console app being edited is not `PhysiLog`
