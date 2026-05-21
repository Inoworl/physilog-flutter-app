# iOS Dev TestFlight Readiness

Issue: #22

This checklist tracks the current `PhysiLog Dev` App Store Connect and
TestFlight setup before wider dev testing.

## Confirmed State

- App Store Connect app: `PhysiLog Dev`
- App ID: `6759681451`
- Bundle ID: `com.physilog.physiLog.dev`
- App Store version: `1.0 提出準備中`
- TestFlight version group: `0.1.0`
- Latest observed build: `35`
- Latest build status: `提出準備完了`
- Latest build group: `Internal Dev`
- Latest build metrics observed: invites `2`, installs `1`, sessions `2`

## Ready For Internal Testing

Use this gate before treating a dev build as testable:

- [ ] Latest TestFlight build is `提出準備完了` or `テスト中`
- [ ] Build is attached to the intended internal group
- [ ] At least one tester can install the build from TestFlight
- [ ] App launches on a physical iOS device
- [ ] Camera permission prompt appears with acceptable copy
- [ ] Photo library permission prompt appears with acceptable copy
- [ ] Record creation, list display, edit, and delete smoke path works
- [ ] Firebase project and bundle ID match the dev environment

## App Store Version Fields

The dev App Store version is not production-facing, but these fields must be
filled if the dev app is submitted for beta review or App Review:

- Screenshots or a decision that dev review does not need storefront assets
- Promotional text
- Description
- Keywords
- Support URL
- Copyright
- App Review username/password if sign-in is required
- App Review contact name, phone, and email
- Review notes explaining the MVP test path
- Release option; prefer manual release for any non-final store submission

## External Testing Decision

Do not enable external testing until these human decisions are recorded in
Issue #22:

- External tester group name
- Beta app description
- Japanese "what to test" text
- Feedback email
- Beta review contact details
- Whether tester notification email should be sent

## CI Expectations

The current workflow is `.github/workflows/deploy_dev_ios.yml`.

Before relying on it for dev distribution:

- [ ] GitHub environment `dev` has all required iOS signing secrets
- [ ] `DEV_GOOGLESERVICE_INFO_PLIST_BASE64` points to the dev Firebase app
- [ ] Fastlane uploads to the `PhysiLog Dev` app identifier
- [ ] Workflow artifacts include the generated IPA or build logs on failure
- [ ] A successful workflow run is linked from Issue #22

## Stop Conditions

Stop and do not distribute if any of these occur:

- The selected build belongs to the prod bundle ID
- The app displays production Firebase data in a dev build
- TestFlight shows processing errors, missing compliance, or an expired build
- Review metadata is partially configured; complete or remove the partial set
