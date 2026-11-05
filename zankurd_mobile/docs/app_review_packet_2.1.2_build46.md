# ZanKurd iOS 2.1.2 (46)

Candidate build: 2.1.2 (46)

Status: local candidate, prepared 15 November 2026 from the commits since build 45. The repository is at
`version: 2.1.2+46` in `zankurd_mobile/pubspec.yaml`. No package has been built,
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
- Content: 696 new questions in six fine-grained categories (ids 406-410
  range). Already live on the server; the app bundle carries the same text.
- Progress sync schema v2: streak-protection ledger and word-list deletion
  markers are synced, so a deleted word does not come back from another device.
- Save-failure protections: a failed local or server write is no longer shown
  as saved, and queued rewards are kept for retry.
- Owner-only management section: it appears only for the owner's administrator
  account. It is not visible to reviewers or to any ordinary or guest account;
  there is nothing in it to test for review.
- Contact address for support and review notes: iletisim@zankurd.com.

## Server-side changes already live

Per commit messages, these server migrations were applied to production before
this build: the 696-question content migration (`2026-11-10_yeni_sorular_2.sql`),
and earlier idempotency tur 9, push tur 8 (with send-push and apple-revoke
functions), security tur 7 (with index rollback file), scale tur 5 and 6,
and content migration for ALAN 7. They change database functions and data but
not the app's public API. This packet does not re-verify them; the owner should
confirm the live state in `zankurd_mobile/supabase/applied.md` before upload.

## Before uploading build 46

1. Confirm `version: 2.1.2+46` in `zankurd_mobile/pubspec.yaml` (already set).
2. Run `zankurd_mobile/tool/ci_yerel.sh --tam` successfully on this exact source.
3. On iOS and Android, test: permission allowed/denied, foreground/background/
   terminated app, refreshed token, account switch, guest deletion, friend
   request, room invitation, notification tap, and transient delivery failure.
4. Verify current light/dark, Kurmancî/Turkish screens, large text and the
   smallest supported viewport (320pt) with fresh screen-tour captures.
5. Verify signing, privacy declarations and store metadata against the actual
   binary. Reuse only review notes confirmed true for that binary.

Upload the exact build 46 only after all gates pass and the owner explicitly
authorizes store submission. Use `zankurd_mobile/tool/surum_paketi.sh` and
`zankurd_mobile/tool/yayinla.sh` for the release operation.

## Evidence boundary

This draft is based on commit messages and code reading. It did not run the
test suite, build a package, or inspect a device. Earlier builds' CI runs are not evidence for build 46.

## Android build verification

Pending. Run `zankurd_mobile/tool/surum_paketi.sh android` on build 46 and record:
artifact path, SHA-256, `bundletool validate` and `jarsigner -verify` results.

## iOS signing verification

Pending. Run `zankurd_mobile/tool/surum_paketi.sh ios` on build 46 and record:
IPA path, SHA-256, version/build (must read 2.1.2 and 46 in app and widget),
strict signature verification and profile expiry.

## Kurmancî review

Pending. The Kurmancî "What's New" text in `yenilikler.txt` is a draft and must
pass the jury before publication: Gemini 3.8 Flash (agy) as primary reviewer, a
second opinion from Grok 4.7 or Muse Spark, and a tie-break when they disagree.
Do not publish the KU text unreviewed.
