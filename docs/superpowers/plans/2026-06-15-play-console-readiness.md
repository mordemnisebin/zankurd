# Play Console Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the ZanKurd mobile app ready for Google Play Console submission with verified Android release artifacts and complete submission guidance.

**Architecture:** Treat `zankurd_mobile` as the production app and keep `zankurd` as a secondary web prototype/admin direction. Keep release changes limited to Android configuration, release documentation, and Play Console submission metadata so existing app behavior stays stable.

**Tech Stack:** Flutter 3.44.1, Dart 3.12.1, Android Gradle, Supabase, Firebase Crashlytics, Google Play Console.

---

### Task 1: Verify Play Console Android Requirements

**Files:**
- Read: `zankurd_mobile/android/app/build.gradle.kts`
- Read: `zankurd_mobile/android/app/src/main/AndroidManifest.xml`
- Read: `zankurd_mobile/pubspec.yaml`
- Modify only if needed: `zankurd_mobile/android/app/build.gradle.kts`

- [ ] **Step 1: Confirm package and signing configuration**

Run:

```powershell
Get-Content -LiteralPath 'C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile\android\app\build.gradle.kts'
Test-Path -LiteralPath 'C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile\android\key.properties'
Test-Path -LiteralPath 'C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile\android\upload-keystore.jks'
```

Expected: `applicationId = "com.zankurd.app"`, release signing points to `key.properties`, and both signing files exist.

- [ ] **Step 2: Confirm Play target API through build output**

Run after release build:

```powershell
Select-String -Path 'C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile\build\app\intermediates\merged_manifest\release\processReleaseMainManifest\AndroidManifest.xml' -Pattern 'targetSdkVersion|versionCode|versionName'
```

Expected: target SDK is API 35 or higher, version code is greater than the previously submitted Play Console version if this is an update, and version name matches `pubspec.yaml`.

### Task 2: Update Release Documentation

**Files:**
- Modify: `zankurd_mobile/README.md`
- Modify: `zankurd_mobile/docs/release_readiness.md`
- Create: `zankurd_mobile/docs/play_console_submission_checklist.md`
- Modify: `zankurd/README.md`

- [ ] **Step 1: Replace placeholder mobile README with real project instructions**

Write a README that identifies `zankurd_mobile` as the production app, lists setup commands, explains Supabase/Firebase roles, and shows release validation commands.

- [ ] **Step 2: Refresh release readiness**

Update release readiness with the current verification date, Play Console API target requirement, artifact paths, signing state, and remaining manual Console fields.

- [ ] **Step 3: Add Play Console checklist**

Create a checklist covering app bundle upload, app access, ads declaration, content rating, target audience, Data Safety, privacy policy, internal testing, and rollout.

- [ ] **Step 4: Clarify web project role**

Update `zankurd/README.md` to state that the React app is a prototype/admin-panel direction, not the Play Store deliverable.

### Task 3: Run Release Verification

**Files:**
- No source edits expected.
- Generated build outputs under `zankurd_mobile/build/`.

- [ ] **Step 1: Set Windows temp variables for Gradle stability**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'C:\src\tmp'
$env:TMP='C:\src\tmp'
$env:TEMP='C:\src\tmp'
```

Expected: directory exists and Gradle uses an ASCII temp path.

- [ ] **Step 2: Run static analysis**

Run:

```powershell
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Run tests**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 4: Build Play Store bundle**

Run:

```powershell
flutter build appbundle --release
```

Expected: `build/app/outputs/bundle/release/app-release.aab` is created.

- [ ] **Step 5: Verify bundle signing**

Run:

```powershell
jarsigner -verify -verbose -certs 'C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile\build\app\outputs\bundle\release\app-release.aab'
```

Expected: `jar verified`.

### Task 4: Final Submission Report

**Files:**
- Read generated verification outputs.

- [ ] **Step 1: Report exact artifact path**

Report the absolute path to the AAB that should be uploaded to Play Console.

- [ ] **Step 2: Report remaining manual Play Console fields**

List only tasks that cannot be completed from the local repository, such as uploading screenshots, completing Data Safety, and entering the privacy policy URL.

- [ ] **Step 3: Note any blocked item**

If analysis, tests, build, signing, or target API verification fails, report the exact command and failure instead of calling the release ready.
