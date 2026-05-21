# iOS Prod App Store Connect Record Reset

Issue: #21

This runbook covers the manual reset of the current App Store Connect prod app
record before creating the final `PhysiLog` production record.

## Current Record

- App Store Connect app name: `PhysiLog`
- Apple ID: `6759681474`
- Bundle ID shown in App Store Connect: `PhysiLog Production - com.physilog.physiLog`
- SKU: `physilog-prod-20260226`
- iOS version state: `1.0 提出準備中`
- TestFlight state: no builds
- Screenshots: 0
- Store metadata: not filled
- App Review information: not filled
- Delete action: `アプリを削除` is visible in App Information

## Decision

Reset the prod App Store Connect record only if all of the following are true:

- The current record still has no TestFlight builds.
- The current record has not been submitted for App Review.
- The current record has no store metadata worth preserving.
- The desired production app name is `PhysiLog` without an internal `prod` suffix.
- The user explicitly approves the destructive delete action in chat or in Issue #21.

Do not delete the record just to change internal labels. The visible store app
name is already `PhysiLog`; internal names such as the SKU or Bundle ID display
name do not appear to users.

## Delete Gate

Before clicking `アプリを削除`, record this checklist in Issue #21:

- [ ] App Store Connect target is `PhysiLog`, Apple ID `6759681474`
- [ ] TestFlight shows no builds for the prod app
- [ ] iOS version is still `1.0 提出準備中`
- [ ] No required metadata exists only in the current record
- [ ] User has approved deletion explicitly

Stop if any item is not true.

## New Record Parameters

Use these as the baseline when recreating the production app:

- App name: `PhysiLog`
- Primary language: Japanese
- Platform: iOS
- Bundle ID: `com.physilog.physiLog`
- SKU: choose a new production SKU because App Store Connect SKUs cannot be reused
- Category: confirm before submission
- User-facing app name must not include `prod`

Record the new Apple ID, SKU, and Bundle ID in Issue #21 after creation.

## Follow-up Tasks

After the new record exists:

- Configure prod iOS signing and GitHub Actions secrets in #26.
- Add or update prod iOS CI workflow in #27.
- Prepare store metadata and screenshots in #28.
- Upload the first prod TestFlight build only after the new record identifiers are
  reflected in the repository and CI configuration.
