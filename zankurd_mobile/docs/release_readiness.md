# ZanKurd Release Readiness

Last updated: 2026-07-03

## Current Release Target

- App name: `ZanKurd`
- Android package: `com.zankurd.app`
- Flutter version: `3.44.1`
- Dart version: `3.12.1`
- App version: `1.5.0+6`
- Play artifact: final AAB regenerated from the ASCII build path after the
  latest onboarding, auth, response-time, and Play-policy readiness fixes.
- Upload copy: `release_packages/zankurd-playstore-release.aab` matches the
  build described below, **but not** the source as of this commit — see
  "Pending before next AAB" below.
- Pending before next AAB: source has moved since the AAB was built
  (real player_id opponent matching in 1v1 duels, `submit_answer`
  response_ms server-side clamp, expanded question explanations).
  Regenerate and re-verify the AAB before the next Play upload.
- `clamp_submit_answer_response_ms.sql`: applied to the live Supabase
  project (2026-07-03) via the Management API. Verified live via
  `pg_get_functiondef` (clamp present in the deployed `submit_answer`) and
  an end-to-end run of `tools/check_live_supabase.py` (room create/join,
  answer submit, leaderboard — all passed against production).

Google Play currently requires new Android apps and updates to target Android 15 / API level 35 or higher. The 2026-06-15 release build targets API level 36.

## Local Signing State

Release signing is configured through ignored local files:

- `android/key.properties`
- `android/upload-keystore.jks`

These files must stay private and backed up. Losing the upload key can block future updates unless Play App Signing key recovery is used.

Template:

- `android/key.properties.template`

## Previous Verified Build: 2026-06-15

The release was verified from the ASCII build path `C:\src\zankurd_mobile` because the Windows analyzer/build tools can fail when the project path contains Turkish characters or a drive substitution.

This build has been superseded by later source changes. Regenerate the final AAB
only after the current source verification passes.

- `dart analyze`: passed, no issues found
- `flutter test`: passed, 83/83 tests
- `flutter build appbundle --release`: passed
- AAB size: 57,286,029 bytes / 54.6 MB
- AAB path: `C:\src\zankurd_mobile\build\app\outputs\bundle\release\app-release.aab`
- Workspace upload copy: `release_packages/zankurd-playstore-release.aab`
- `jarsigner -verify -verbose -certs`: `jar verified`
- Package: `com.zankurd.app`
- Version code: `4`
- Version name: `1.3.0`
- Min SDK: `24`
- Target SDK: `36`
- AAB SHA256: `D7B4A0003B73AAD57E1B94BA2B42548383B5F615234CCA240D54881CFF3CA2D7`
- SHA256 list: `release_packages/SHA256SUMS.txt`

`jarsigner` reports that the upload certificate is self-signed and has no timestamp. This is normal for Android upload keys; Play App Signing validates the uploaded AAB and manages distribution signing.

## Current Source Verification: 2026-07-03

After the coin-joker system (`spend_coins` RPC), category-mastery system
(`MasteryStore`), the profile tab-refresh fix (`refreshSignal`), real-image
import, release UI polish, web runtime fixes, mobile OAuth redirect fix, and
tablet release-device audit:

- `dart analyze`: passed, no issues found
- `flutter test`: passed, 240/240 tests from `C:\src\zankurd_mobile`
- `flutter build web --release`: passed
- `flutter build apk --release`: passed; test APK path
  `C:\src\zankurd_mobile\build\app\outputs\flutter-apk\app-release.apk`
  updated at 2026-06-21 19:01:35
- Local Playwright web audit: passed end-to-end — onboarding, guest auth,
  profile-name gate, home, categories, leaderboard, and profile all verified
  with no runtime console errors
- Final AAB: regenerated from `C:\src\zankurd_mobile`
- AAB path: `C:\src\zankurd_mobile\build\app\outputs\bundle\release\app-release.aab`
- Workspace upload copy: `release_packages/zankurd-playstore-release.aab`
- AAB size: 111,467,387 bytes / 106.3 MB
- AAB SHA256: `0FD6D81F6B1CD578F5B051EEDFB984386AC811B6A5D8355E14BB9D3B6D9F7681`
- `jarsigner -verify`: `jar verified`
- Merged release manifest: package `com.zankurd.app`, versionCode `6`,
  versionName `1.5.0`, targetSdkVersion `36`
- Daily reminders now use inexact scheduling; `SCHEDULE_EXACT_ALARM` is not
  present in the merged release manifest.
- Latest polish audit covered local room-code validation, leaderboard podium,
  landscape quiz layout, centered high-quality onboarding logo rendering,
  web-safe home header runtime, web-safe sync connectivity handling, and
  Supabase question queries that avoid missing optional localized columns.
- Tablet release APK audit covered onboarding logo placement, auth contrast,
  Google OAuth deep-link return, online room creation, and live leaderboard
  loading. The final leaderboard text-contrast fix and landscape quiz layout
  were verified on the tablet after reinstalling the release APK.
- Supabase Auth redirect configuration is set for mobile:
  `site_url = com.zankurd.app://login-callback/` and allow-list contains the
  same deep link. Google OAuth returned from Chrome into the app on the tablet.
- Live Supabase multiplayer check: passed. The check creates two anonymous
  users, creates a room, joins by code, starts the game, submits answers, and
  verifies leaderboard visibility.
- Live leaderboard cleanup: passed. Test/demo profiles and associated rooms,
  room players, answers, coin rows, profiles, and auth users were removed after
  verification.
- Final AAB: not regenerated yet

## Verification Commands

Run from `C:\src\zankurd_mobile` after syncing the workspace copy.

```powershell
New-Item -ItemType Directory -Force -Path 'C:\src\tmp'
$env:TMP='C:\src\tmp'
$env:TEMP='C:\src\tmp'
flutter analyze
flutter test
flutter build appbundle --release
jarsigner -verify -verbose -certs 'build/app/outputs/bundle/release/app-release.aab'
```

Expected results before producing the final Play AAB:

- `dart analyze`: no issues
- `flutter test`: all tests pass
- App bundle exists at `build/app/outputs/bundle/release/app-release.aab`
- `jarsigner`: `jar verified`
- Merged release manifest shows target SDK API 35 or higher

## Supabase Steps Before Wider Sharing

The live Supabase project should have these SQL files applied before internal testing or production rollout:

1. `supabase/public_read_policies.sql`
2. `supabase/online_room_policies.sql`
3. `supabase/online_game_sync.sql`
4. `supabase/leaderboard_view.sql`
5. `supabase/submit_answer_function.sql`
6. `supabase/daily_spin_rpc.sql`
7. `supabase/quiz_reward_rpc.sql`
8. `supabase/coin_policies.sql`
9. `supabase/delete_my_account_rpc.sql`

For the current mobile build, also apply:

10. `supabase/online_multiplayer_ready.sql`

This patch creates the `join_room_by_code`, `start_room_game`, `finish_room_game`,
and `submit_answer` RPCs expected by the app. It has been applied to the live
Supabase project and verified by `tools/check_live_supabase.py`.

Anonymous auth must be enabled in Supabase Authentication settings if the app is shipped with anonymous-first onboarding.

## Play Console Manual Items

These cannot be completed from the local repository and must be filled in Play Console:

- Upload `app-release.aab` to Internal testing first.
- Complete App access. If reviewers can use anonymous login, state that no test credentials are required.
- Complete Ads declaration. Current app should be marked as no ads unless an ad SDK is added.
- Complete Content rating questionnaire for an education/trivia quiz app.
- Complete Target audience and content. Do not mark as child-directed unless the product is intentionally prepared for the Families policy.
- Complete Data Safety based on Supabase account/game data and Firebase Crashlytics diagnostics.
- Publish `docs/privacy_policy.html` at a public HTTPS URL and enter that URL in Play Console.
- Upload phone screenshots and feature graphic.
- Add release notes from `docs/release_notes_internal.md`.

## Recommended First Rollout

1. Upload to Internal testing.
2. Install from the Play internal testing link on at least one real Android device.
3. Test anonymous login, profile name, daily quiz, category quiz, daily spin, leaderboard, question report, and account deletion request.
4. Fix any Play Console pre-launch report issue.
5. Promote to Closed testing or Production only after the internal track is clean.
