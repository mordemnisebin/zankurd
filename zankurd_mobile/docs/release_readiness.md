# ZanKurd Release Readiness

Last updated: 2026-06-15

## Current Release Target

- App name: `ZanKurd`
- Android package: `com.zankurd.app`
- Flutter version: `3.44.1`
- Dart version: `3.12.1`
- App version: `1.3.0+4`
- Play artifact: final AAB not regenerated after the latest online-room and
  real-image changes.
- Upload copy: `release_packages/zankurd-playstore-release.aab` is a previous
  build and must not be treated as the final Play upload.

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

## Current Source Verification: 2026-06-15

After the latest online-room fallback fixes and real-image import:

- `dart analyze`: passed, no issues found
- `flutter test`: passed, 99/99 tests
- Final AAB: not regenerated yet
- Live Supabase multiplayer check: blocked until
  `supabase/online_multiplayer_ready.sql` is applied in the Supabase SQL editor.

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
and `submit_answer` RPCs expected by the app. The live check currently fails with
`PGRST202` until that patch is installed.

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
