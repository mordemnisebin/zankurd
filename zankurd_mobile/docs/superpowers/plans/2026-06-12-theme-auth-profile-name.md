# Theme Auth Profile Name Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make dark/light mode affect the visible UI, make auth redirects/provider errors user-friendly, and require an online player name after any sign-in method.

**Architecture:** Theme colors stay centralized in `AppTheme`, with context-aware helpers used by common UI shells and panels so `ThemeProvider` changes repaint screens. Auth keeps using `AuthProvider`, adding explicit redirect URLs and clearer Supabase provider errors. Profile completion is enforced in `AppShell` after auth and before the tab shell by checking `ZanKurdRepository.getProfileName()`.

**Tech Stack:** Flutter, provider, shared_preferences, Supabase Flutter Auth, widget tests.

---

### Task 1: Theme Mode Applies To Visible UI

**Files:**
- Modify: `lib/src/theme/app_theme.dart`
- Modify: common screens/widgets using `AppTheme.bgGradient`, `surface`, `border`, and text colors.
- Test: `test/widget_test.dart`

- [x] Add a failing widget test named `theme toggle changes visible home surface colors`.
- [x] Run the targeted test and verify it fails because visible surface colors do not change.
- [x] Add context-aware helpers in `AppTheme`: `backgroundGradient(context)`, `surfaceColor(context)`, `surfaceHiColor(context)`, `borderColor(context)`, `textPrimaryColor(context)`, `textSubColor(context)`, `textMutedColor(context)`, plus light palette constants.
- [x] Update `AppPanel`, `HomeScreen`, `HomeHeader`, onboarding and major tab wrappers to use context-aware colors where the mode must visibly change.
- [x] Run the targeted test and verify it passes.

### Task 2: Auth Redirects And Provider Errors

**Files:**
- Modify: `lib/src/providers/auth_provider.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Test: `test/widget_test.dart`

- [x] Add a failing unit/widget test for translating Supabase `unsupported provider is not enabled` to a clear Turkish error.
- [x] Add `com.zankurd.app://login-callback/` redirect to email sign-up, password reset, and Google OAuth calls.
- [x] Add an Android deep link intent-filter for scheme `com.zankurd.app` and host `login-callback`.
- [x] Update error translation for unsupported provider and redirect validation failures.
- [x] Run the targeted auth error test and verify it passes.

### Task 3: Required Player Name Gate

**Files:**
- Create: `lib/src/screens/profile_name_gate_screen.dart`
- Modify: `lib/src/screens/app_shell.dart`
- Modify: `lib/src/data/mock_zankurd_repository.dart`
- Test: `test/widget_test.dart`

- [x] Add a failing widget test named `auth requires player name before home`.
- [x] Implement `ProfileNameGateScreen` with localized prompt, validation, save button, and repository update.
- [x] Update `AppShell` to load `getProfileName()` after auth, show the gate until the local completion flag is saved, and continue after saving.
- [x] Ensure mock repository supports empty profile name in tests and updates it in memory.
- [x] Run the targeted profile gate test and verify it passes.

### Task 4: Verification And Tablet Run

**Files:**
- No source changes expected after fixes.

- [x] Run `dart format`.
- [x] Sync to `C:\src\zankurd_mobile`.
- [x] Run `flutter analyze`.
- [x] Run `flutter test`.
- [x] Commit.
- [x] Run tablet with Supabase dart-defines.
