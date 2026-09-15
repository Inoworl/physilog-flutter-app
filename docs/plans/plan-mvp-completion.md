# Three-plan MVP completion

## Agreed scope

- Free: one athlete, three events. Personal/family: five athletes, unlimited events. Team: unlimited athletes/events, measurement sessions and CSV.
- Existing records are never deleted by a downgrade. History remains readable and deletable. New measurements and record changes require an athlete/event selected within the current plan's limits.
- Sharing with parents/athletes remains deferred (#99). CSV (#109) is independent.
- Purchase restoration and existing automatic entitlement refresh remain supported.

## Execution

1. Add domain tests for bounded recording selection and account-independent plan fixtures (`test/features/billing/domain/recording_scope_test.dart`).
2. Add a per-account, per-data-store local selection repository and recording access service. Enforce selection and current identity on every record write, and current quotas on athlete/event creation. Recheck Team capability for session attempts, including updates.
3. Add selection management to the Manage screen and a notice to measurement entry screens. Keep all history views unfiltered by plan.
4. Add a pure CSV encoder and guarded export service. Export the current user's records filtered by athlete, event and inclusive local calendar dates. Use UTF-8 BOM, CSV escaping, formula-safe text and minimal columns. Weight sets remain in a dedicated text column so their data is not silently lost.
5. Add a CSV action to the Records tab with preview/confirmation and the platform share sheet. Keep the shared file in application temporary storage, clean old export files on subsequent use, and never automatically send it anywhere.
6. Test plan changes, account switching, loading/error denial, over-limit history, CSV data isolation/escaping, and persistence. Use existing fake repositories, not production grants or new login credentials.
7. Run FVM format, targeted tests, full tests and analysis. Record unresolved environment or store checks separately.

## Boundaries

- Selection is local to this installation and scoped to the Firebase user/data-store mode; it does not add Firestore paths. A new device must select again if it exceeds plan limits.
- Client checks are not a server-side quota/security boundary. Existing Firebase ownership Rules remain authoritative for data isolation.
- Do not infer an additional offline subscription grace period from a cached billing-issue flag. Offline entitlement freshness remains a separate #108 acceptance item until its store/cache policy is agreed and verified.
- No credential reads, account provisioning, live purchases, production deployments, PR merging or edits to the existing Commons working tree.
- Real account preparation and iOS/Android store validation remain #110 tasks; fixtures are not evidence of a successful real purchase.

## Implemented and verified locally

- Recording scope, persistence, save-time guards, creation quota checks, session checks, selection UI, CSV workflow and three fixed-plan previews are implemented in `feature/plan-mvp-completion`.
- `fvm flutter test --no-pub`: 418 tests passed, with no exclusions.
- CSV date-boundary suite with `TZ=America/New_York`: 11 tests passed, including the 25-hour daylight-saving transition day.
- Analysis of all 36 changed Dart files: no issues. Full analysis has one pre-existing `prefer_const_constructors` info at `lib/features/measurement/presentation/widgets/session_video_loop.dart:458`; no unrelated code was changed to silence it.
- Android mock debug APK and iOS dev-scheme Simulator debug app both build with `lib/main_mock.dart` and `PREVIEW_PLAN=team`.
- An isolated iPhone 16 Pro / iOS 18.4 Simulator launched the Team preview; the home screen showed all six dummy athletes and the measurement-session action. The temporary simulator was shut down and removed. This does not verify the native CSV share sheet or real store purchases.
- `git diff --check` passes. Added-line/new-file scanning found no matches for the checked private-key, GitHub-token or SDK-key formats; this is not a guarantee that a general secret scanner covers every format.
- Review regressions include stale account data in CSV/selection dialogs, removed CSV dropdown targets, date/time normalization, current Team rights when updating a session, and explicit plan/storage fixtures for existing tests.
- User-facing scope, preview commands, CSV privacy and unresolved acceptance checks are documented in `docs/plan_mvp_verification.md`.

These are local source/test/build results, not a merged PR, deployment, production configuration audit, or new real-store purchase test. No credentials were opened, no real test accounts were provisioned, and the existing Commons working tree was left unchanged.
