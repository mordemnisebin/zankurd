# Auth Online Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make first launch and login explicit, remove symbolic online data fallbacks, and expose quick language/theme controls on the home header.

**Architecture:** Auth state remains in `AuthProvider`; mock/test mode no longer counts as authenticated until the user chooses guest. Supabase repository keeps online reads authoritative for leaderboard and balances: failures return empty/zero instead of fake leaderboard rows. UI polish stays in focused widgets/providers.

**Tech Stack:** Flutter, provider, shared_preferences, Supabase repository pattern.

---

### Task 1: Explicit Auth In Mock/Test Mode

**Files:**
- Modify: `lib/src/providers/auth_provider.dart`
- Modify: `test/widget_test.dart`

- [x] Add a mock/test auth state to `AuthProvider.test({bool authenticated = false})`.
- [x] Change `isAuthenticated` so `_client == null` uses the mock state, not unconditional true.
- [x] Make `signInAsGuest()` set the mock state and notify listeners when no Supabase client exists.
- [x] Update widget tests to keep explicit authenticated states where needed.
- [x] Verify targeted mock auth tests pass.

### Task 2: Online Data Must Not Fall Back To Symbolic Leaderboard

**Files:**
- Modify: `lib/src/data/supabase_zankurd_repository.dart`
- Modify: `test/widget_test.dart`

- [x] Change `loadLeaderboard()` catch path to return `const []`.
- [x] Change `loadCoinBalance()` catch path to return `0`.
- [x] Change `loadFavoriteQuestions()` catch path to return `const []`.
- [x] Change `awardSpinCoins()` catch path to return `0`.
- [x] Keep full widget coverage passing with empty online states supported.
- [x] Verify full test suite passes.

### Task 3: Onboarding Brand Polish

**Files:**
- Modify: `lib/src/screens/onboarding_screen.dart`
- Modify: `test/widget_test.dart`

- [x] Replace the plain top logo with an animated brand lockup: gradient badge, app name, short subtitle.
- [x] Keep `Atla` and `Başla` behavior unchanged.
- [x] Add a widget expectation for app name on onboarding.
- [x] Verify first-launch onboarding test passes.

### Task 4: Home Header Quick Controls

**Files:**
- Create: `lib/src/providers/theme_provider.dart`
- Modify: `lib/main.dart`
- Modify: `lib/src/screens/home/home_header.dart`
- Modify: `test/widget_test.dart`

- [x] Add `ThemeProvider` with persisted dark/light/system preference.
- [x] Wire `ZanKurdApp` to `ThemeProvider` and `MaterialApp.themeMode`.
- [x] Add compact language toggle and theme toggle next to coin in `HomeHeader`.
- [x] Add tests asserting `TR/KU` and theme icon controls are visible on home.
- [x] Verify targeted home tests pass.

### Task 5: Full Verification And Tablet Run

**Files:**
- No source changes expected.

- [x] Run `dart format`.
- [x] Sync repo to `C:\src\zankurd_mobile`.
- [x] Run `flutter analyze`.
- [x] Run `flutter test`.
- [x] Commit.
- [x] Run tablet with Supabase dart-defines.
