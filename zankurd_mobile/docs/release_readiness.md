# ZanKurd Release Readiness

Last updated: 2026-06-08

## Current Build Outputs

- Android release APK:
  - `C:\src\zankurd_mobile\build\app\outputs\flutter-apk\app-release.apk`
- Android Play Store bundle:
  - `C:\src\zankurd_mobile\build\app\outputs\bundle\release\app-release.aab`
- Web release:
  - `C:\src\zankurd_mobile\build\web`
- Windows release executable:
  - `C:\src\zankurd_mobile\build\windows\x64\runner\Release\zankurd.exe`
- Windows release ZIP:
  - `C:\src\zankurd_mobile\build\release_packages\zankurd-windows-x64-release.zip`

## Validation

- `flutter analyze`: passed
- `flutter test`: passed, 14 tests
- Android release APK build: passed
- Android release AAB build: passed
- APK signing verification: passed with APK Signature Scheme v2
- Web release build: passed
- Windows release build: passed

## Supabase Steps Before Wider Sharing

Run this SQL once so coin balance and quiz rewards persist for signed-in/anonymous users:

- `C:\src\zankurd_mobile\supabase\coin_policies.sql`

Already required policies/features:

- Anonymous auth enabled in Supabase Authentication settings.
- Public read policies for categories/questions.
- Room policies and RPC files installed.
- Leaderboard view installed.
- `submit_answer` RPC installed.

## Android Signing

Release signing support is now wired through:

- `android\key.properties`
- `android\upload-keystore.jks`

These files are intentionally ignored by git and must be kept private and backed up. Losing the upload keystore can block future app updates unless Play App Signing recovery is used.

Template:

- `android\key.properties.template`

## Remaining Store-Quality Work

- Create final store screenshots and feature graphic.
- Add privacy policy URL.
- Add app icon/splash polish if a designer later provides final brand assets.
- Decide whether to keep anonymous-first flow or expose email/Google auth.
- Add daily contest/tournament/reward screens for fuller Pirs-like breadth.
