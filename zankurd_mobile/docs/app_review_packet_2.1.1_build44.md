# ZanKurd iOS 2.1.1 (44)

Candidate build: 2.1.1 (44)

Status: local candidate. The Android production bundle and signed iOS IPA were
built and verified locally on 31 October 2026. Physical-device testing is deferred by the owner.
Live rollout and store submission are pending.

## Product and review path

ZanKurd offers Kurmancî/Turkish language learning and quizzes. Core solo learning
is available offline. Social features require connectivity and Supabase.
Continue as a guest, complete the requested profile setup, try a lesson and a
solo quiz, then inspect Play, Friends, room creation, and Settings. A second
test account/device is needed to verify friend requests and room invitations.
Account deletion is available from Settings. Do not include credentials here.

## Subscription availability

ZanKurd Pro is NOT offered in this candidate. The feature flag is
`kProEnabled = false`. Its Home tab and Settings purchase entry points are
hidden. Subscription purchases and Restore Purchases are unavailable through
the normal application routes.

## Candidate changes to verify

- Language placement uses approved language-skill questions rather than the
  general knowledge pool; score thresholds remain unchanged.
- Streak protection uses a stable solo transaction identity and recoverable
  idempotent charging; ambiguous legacy charges must not be charged again.
- Failed storage writes must not silently discard queued rewards or report
  a placement result as saved.
- The weekly streak strip uses the same recovered and frozen day records as
  the monthly calendar, while retaining legacy answer history.
- Room choices extend to 50 questions and 120 seconds, subject to the server
  migration gate in `room_limits_rollout_2026_10_31.md`.
- Push token refresh, sign-in and connectivity recovery register the device.
  Reliable server delivery requires the separately reviewed V2 outbox rollout.

## Before uploading build 44

1. Run `tool/ci_yerel.sh --tam` successfully on this exact source.
2. Confirm room limits and push V2 deployment against live definitions; do not
   deploy from historical function bodies or enable incomplete worker versions.
3. On iOS and Android, test permission allowed/denied, foreground/background/
   terminated app, refreshed token, account switch, friend request, acceptance,
   room invitation, notification tap, and transient delivery failure.
4. Verify the current light/dark and Kurmancî/Turkish screens, large text and
   smallest supported viewport; the 28 October renders are not current proof.
5. Verify signing, privacy declarations and current store metadata against the
   actual binary. Reuse only review notes confirmed true for that binary.

Upload the exact build 44 only after all gates pass and the owner explicitly
authorizes store submission. Use `tool/yayinla.sh` for the release operation.

## Evidence boundary

The standard local full CI completed successfully on 31 October 2026,
including 214 screen-tour tests, 7,608 tests (3 skipped), and four application
flows. A debug simulator preview was built and inspected. Physical-device and
production push delivery verification remain outstanding. No live migration,
Edge deployment, store upload or real-user notification was performed.
The final run exited successfully in 512 seconds; its log is
`/tmp/zk-final-complete-ci.log`. It includes the new weekly recovery regression.

## Android build verification

`tool/surum_paketi.sh android` produced the production-configured 2.1.1 (44)
bundle. The existing build script confirmed the required configuration in the
compiled binary without exposing its values. `bundletool validate` and
`jarsigner -verify` both succeeded. The bundle is approximately 167.3 MB.
The verifier reported the self-signed upload certificate, missing timestamp,
and stream-reading ZIP manifest warnings. Its file-based signature verification
completed with `jar verified`. Store-side acceptance remains pending.

Artifact path: `build/app/outputs/bundle/release/app-release.aab`.
SHA-256: `5dbd4158cb6e3fe54e9b3c442da5389052edc9d2fd4792ce7ad71aa918e61b9a`.

Build log: `/tmp/zk-final-android-build.log`.
Validation log: `/tmp/zk-final-aab-validate.log`.
Signature log: `/tmp/zk-final-aab-signature.log`.

## iOS signing verification

The signed production archive and App Store IPA were built on 31 October
2026. The first export unexpectedly changed build 44 to 43. Setting
`manageAppVersionAndBuildNumber=false` in the shared export options preserved
the source version. Both publishing scripts already use that options file.
Gemini 4 Argon independently approved this correction.

The same archive was exported again to verify the correction, then rebuilt
with the final calendar fix. The final IPA contains version 2.1.1,
build 44 in both the main application and its widget. Strict signature
verification passed for the application, embedded frameworks and widget.
The distribution profile is unexpired. Production APNs, Apple sign-in,
associated domains and the shared app group are present. Debug execution
permission is disabled.

The verified IPA is `build/ios/ipa/ZanKurd.ipa`.
Its SHA-256 is `5d4c3e4b023a0a010b05c4e9166d62aef7f7a7b430ae8c24c7fdddcd3a10aa2f`.
Verification is recorded in `/tmp/zk-signed-ios-verification.json`.
The final archive/export log is `/tmp/zk-final-signed-ios.log`;
the earlier same-archive experiment is `/tmp/zk-ipa-fixed-export.log`.
Export used a temporary options copy with
symbol upload disabled. Physical-device execution and store upload are pending.

## Kurmancî review

Gemini 3.8 Flash approved all 16 added or reused KU/TR pairs. Codex also
checked their spelling, meaning and original lesson references. The weekday
translations and five sentences match existing lesson or approved question
content. The new heading `Rojên hefteyê` and reversed river-name answer
variant preserve the intended meanings.

Grok 4.7 and fallback Claude Sonnet 5.5 both returned quota errors. This
candidate therefore has Gemini and Codex review; the project’s specifically
requested Gemini/Grok pair remains unavailable. Review evidence is in
`/tmp/zk-ku-pair-final-z056kral/`.
Grok was retried for the same 16 pairs in this follow-up and again returned
the account usage-limit error without reviewing the text.
