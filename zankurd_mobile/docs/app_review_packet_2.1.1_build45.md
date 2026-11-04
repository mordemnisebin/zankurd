# ZanKurd iOS 2.1.1 (45)

Candidate build: 2.1.1 (45)

Status: local candidate, prepared 4 November 2026 from the commit range
`956f0904..HEAD` (since the build 44 code). The repository is at
`version: 2.1.1+45` in `zankurd_mobile/pubspec.yaml`. No package has been built,
signed, uploaded or submitted yet. Live rollout and store submission are
pending owner approval.

## Product and review path

ZanKurd offers Kurmancî/Turkish language learning and quizzes. Core solo learning
is available offline. Social features (friends, duels, rooms, tournaments)
require connectivity and Supabase.

Suggested reviewer path:
1. Launch the app and choose "Continue as guest" (Misafir olarak devam et).
   Complete the requested profile setup, including the age declaration.
2. Try one lesson and one solo quiz; they work offline.
3. Open Play (Oyna) to see duels, rooms and the tournament entry point.
4. Open Friends and room creation. A second test account/device is needed to
   verify friend requests and room invitations.
5. Open Settings (Ayarlar) to see privacy options and account actions.

Account deletion: Settings → Hesap işlemleri → Hesabımı sil (Settings → Account
actions → Delete my account). The flow is intended to work for guest accounts as
well as registered accounts; the code path calls the server delete, then signs
out and clears local data for that account. **Owner must confirm on a physical
device or simulator for a guest account before submission** — this draft does
not claim it has been run.

Age gate: the first-run "13 yaşından büyük müsün?" declaration is stored
locally (`lib/src/data/age_gate_store.dart`). From this build, an adult
declaration is bound to the signed-in account; a child declaration remains
device-wide. Reviewers may answer either way; the answer only controls the
features described in Settings → Hesap ve gizlilik.

Moderation paths (user-generated content in rooms, profiles and chat):
- Report a player profile: the player moderation button on the avatar/name
  (`lib/src/widgets/player_moderation_button.dart`), calls `reportPlayerProfile`.
- Block a player: same button, calls `blockPlayer`; blocked players' room
  messages are hidden for the blocking user.
- Mute a player's room chat: local mute via `ChatMuteStore`; it hides the
  player's messages for the muting user only.
- Room chat has long-press access to the same actions.

## Subscription availability

ZanKurd Pro is NOT offered in this candidate. The feature flag is
`kProEnabled = false` (`zankurd_mobile/lib/src/config/feature_flags.dart`).
Its Home tab and Settings purchase entry points are hidden. Subscription
purchases and Restore Purchases are unavailable through the normal application
routes.

In-app items (jeton, joker, seri koruması, çerçeveler) are bought with virtual
currency earned in the app. **Owner must confirm before submission whether any
of these can be bought with real money in this build; if so, the in-app purchase
declarations and reviewer notes must cover them.**

Tournaments are enabled (`kTournamentEnabled = true`). Weekly league is disabled
(`kWeeklyLeagueEnabled = false`).

## Candidate changes to verify

User-visible:
- Duel and room matchmaking: the 20-second automatic cancel no longer races a
  join that is still in progress.
- Streak protection and daily wheel: a retried purchase or spin no longer grants
  a second benefit when the first response was lost (client keeps a persistent
  operation identity; the server applies one effect per key).
- Streak repair: the intent is stored before the paid call starts and is
  reconciled on next launch.
- Failed local storage writes no longer discard queued rewards, and a placement
  or lesson result is not reported as saved when the write failed.
- Switching accounts keeps local progress scoped per account; a guest sign-out
  clears only that guest's receipts.
- Push: sign-out removes only this device's token; notification taps, duplicate
  delivery (collapse id per job), and the notification preference banner are
  corrected. Reliable server delivery still depends on the separately reviewed
  push V2 rollout.
- Room chat: a player who is blocked is shown as blocked; the mute and block
  controls agree with what is displayed.
- Kurmancî: interface strings approved by a multi-model review; plural form
  for count 1 fixed ("1 peyv"); some question answers and explanations corrected;
  duplicate question prompts rewritten (no question removed).
- Privacy text now matches the real behaviour: word list backup for registered
  accounts, guest progress is cleared on guest sign-out, analytics and crash
  reports are off by default, and the deletion path names the correct menu.
- Layout and accessibility: forced-update screen can scroll; semantic labels
  for correct/wrong answers and charts; dialogs and pages scroll at 320pt with
  2x text; touch targets enlarged where they were too small.

Not yet confirmed for this build (check before submission):
- Room options of 50 questions and 120 seconds (from build 44 candidate) appear
  only when the server gate is open; the gate status must be checked against
  live definitions (`docs/room_limits_rollout_2026_10_31.md`). No commit in
  `956f0904..HEAD` changes this; do not describe it as shipped unless verified.

## Server-side changes already live

Per commit messages, these server migrations were applied to production before
this build: idempotency tur 9, push tur 8 (with send-push and apple-revoke
functions), security tur 7 (with index rollback file), scale tur 5 and 6,
and content migration for ALAN 7. They change database functions and data but
not the app's public API. This packet does not re-verify them; the owner should
confirm the live state in `zankurd_mobile/supabase/applied.md` before upload.

## Before uploading build 45

1. Confirm `version: 2.1.1+45` in `zankurd_mobile/pubspec.yaml` (already set).
2. Run `zankurd_mobile/tool/ci_yerel.sh --tam` successfully on this exact source.
3. On iOS and Android, test: permission allowed/denied, foreground/background/
   terminated app, refreshed token, account switch, guest deletion, friend
   request, room invitation, notification tap, and transient delivery failure.
4. Verify current light/dark, Kurmancî/Turkish screens, large text and the
   smallest supported viewport (320pt) with fresh screen-tour captures.
5. Verify signing, privacy declarations and store metadata against the actual
   binary. Reuse only review notes confirmed true for that binary.

Upload the exact build 45 only after all gates pass and the owner explicitly
authorizes store submission. Use `zankurd_mobile/tool/surum_paketi.sh` and
`zankurd_mobile/tool/yayinla.sh` for the release operation.

## Evidence boundary

This draft is based on commit messages and code reading. It did not run the
test suite, build a package, or inspect a device. The earlier build 44 CI
(`214 screen-tour tests, 7,608 tests`) is not evidence for build 45.

## Android build verification

Pending. Run `zankurd_mobile/tool/surum_paketi.sh android` on build 45 and record:
artifact path, SHA-256, `bundletool validate` and `jarsigner -verify` results.

## iOS signing verification

Pending. Run `zankurd_mobile/tool/surum_paketi.sh ios` on build 45 and record:
IPA path, SHA-256, version/build (must read 2.1.1 and 45 in app and widget),
strict signature verification and profile expiry.

## Kurmancî review

Pending. The Kurmancî "What's New" text in `yenilikler.txt` is a draft and must
pass the jury before publication: Gemini 3.8 Flash (agy) as primary reviewer, a
second opinion from Grok 4.7 or Muse Spark, and a tie-break when they disagree.
Do not publish the KU text unreviewed.
