# ZanKurd iOS 2.1.1 (42)

Candidate build: 2.1.1 (42)

Status: local candidate. The Android production bundle was built and verified
locally on 31 October 2026. Physical-device testing is deferred by the owner.
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
- Room choices extend to 50 questions and 120 seconds, subject to the server
  migration gate in `room_limits_rollout_2026_10_31.md`.
- Push token refresh, sign-in and connectivity recovery register the device.
  Reliable server delivery requires the separately reviewed V2 outbox rollout.

## Before uploading build 42

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

Upload the exact build 42 only after all gates pass and the owner explicitly
authorizes store submission. Use `tool/yayinla.sh` for the release operation.

## Evidence boundary

The standard local full CI completed successfully on 31 October 2026,
including 214 screen-tour tests, 7,607 tests (3 skipped), and four application
flows. A debug simulator preview was built and inspected. Physical-device and
production push delivery verification remain outstanding. No live migration,
Edge deployment, store upload or real-user notification was performed.

## Android build verification

`tool/surum_paketi.sh android` produced the production-configured 2.1.1 (42)
bundle. The existing build script confirmed the required configuration in the
compiled binary without exposing its values. `bundletool validate` and
`jarsigner -verify` both succeeded. The bundle is approximately 167.3 MB.
The verifier reported the self-signed upload certificate, missing timestamp,
and stream-reading ZIP manifest warnings. Its file-based signature verification
completed with `jar verified`. Store-side acceptance remains pending.

Artifact path: `build/app/outputs/bundle/release/app-release.aab`.
SHA-256: `89d55c20a3673903041c31eb527adfa6628d4e6004921145dc803be92f09f6fc`.

Build log: `/tmp/zk-final-android-build.log`.
Validation log: `/tmp/zk-final-aab-validate.log`.
Signature log: `/tmp/zk-final-aab-signature.log`.

## iOS compilation verification

`flutter build ios --release --no-codesign` with the existing production
configuration completed successfully on 31 October 2026. The output is
`build/ios/iphoneos/Runner.app`, version 2.1.1 (42). This verifies native and
Dart release compilation. Signing, provisioning and device execution remain
separate checks before distribution. Build log: `/tmp/zk-final-ios-build.log`.

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
