# ZanKurd V2 Competition-First UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ZanKurd feel like a clear, competition-first Kurdish quiz app while keeping a visible but optional learning path and making mobile Chrome navigation painless.

**Architecture:** Keep the existing repository and quiz flows, but simplify the shell to three primary destinations: Ana Sayfa, Yarış, and Profil. Recompose existing widgets instead of introducing a second navigation system; keep learning as a medium-sized home card and keep post-quiz actions strictly within the competition loop.

**Tech Stack:** Flutter/Dart, existing Provider state, existing `ZanKurdRepository`, Flutter widget tests, Playwright live-web smoke.

## Global Constraints

- Do not remove existing quiz, room, tournament, shop, favorite, or learning capabilities; move them behind clearer hierarchy.
- Keep stable category IDs and Supabase contracts unchanged.
- Keep Kurmancî and Turkish labels synchronized through `CategoryNames`.
- Do not redirect users from quiz results into learning automatically.
- Keep profile settings reachable from the first viewport on mobile and web.
- Run `dart analyze` before completion; run targeted Flutter tests and live Playwright smoke after UI changes.

---

### Task 1: Lock the three-destination shell

**Files:**
- Modify: `lib/src/screens/app_shell.dart`
- Test: `test/app_shell_navigation_test.dart` (create if absent)

**Interfaces:**
- Consumes: existing `HomeScreen`, `PlayHubScreen`, `ProfileScreen`, `ZanKurdRepository`.
- Produces: a shell with exactly three user-facing destinations and stable keys for test assertions.

- [ ] **Step 1: Write the failing test** asserting that the shell exposes `Sereke`, `Yarış`, and `Profîl` in Kurmancî and `Ana Sayfa`, `Yarış`, and `Profil` in Turkish, while no separate `Fêr Bibe` or `Civak` destination is exposed.
- [ ] **Step 2: Run the targeted test and verify it fails** because the current shell still exposes five destinations.
- [ ] **Step 3: Change `AppShell._buildScaffold`** so `IndexedStack` contains `HomeScreen`, `PlayHubScreen`, and `ProfileScreen`; keep community and learning reachable from secondary actions rather than bottom navigation.
- [ ] **Step 4: Update nav tour targets and copy** to describe the three destinations without claiming that learning and community are primary tabs.
- [ ] **Step 5: Run the targeted test and verify it passes.**

### Task 2: Recompose the home screen around competition

**Files:**
- Modify: `lib/src/screens/home_screen.dart`
- Modify: existing home widgets under `lib/src/screens/home/` only where required
- Test: `test/home_competition_first_test.dart`

**Interfaces:**
- Consumes: repository category list, current coin/streak state, existing quick-play and learning widgets.
- Produces: home hierarchy with one primary `Hemen Yarış` action, secondary daily/friends actions, and a medium optional learning card.

- [ ] **Step 1: Write failing widget tests** asserting the first viewport contains `Hemen Yarış`, `Günün Yarışması`, `Arkadaşınla Oyna`, and `Öğrenme Yolun`; assert `Öğrenme Yolun` is not the primary action.
- [ ] **Step 2: Run the test and verify the current home hierarchy fails** because multiple cards compete for first attention.
- [ ] **Step 3: Reorder the existing home sections** so the primary competition card occupies the strongest visual position; place the learning path after daily and social competition cards at medium size.
- [ ] **Step 4: Keep `onOpenLearning` available** from the learning card, but remove any forced learning transition from competition actions.
- [ ] **Step 5: Add responsive constraints** for phone-width and desktop-width layouts so the first viewport does not clip the primary action or settings entry points.
- [ ] **Step 6: Run the targeted widget test and verify it passes.**

### Task 3: Simplify the play hub without deleting modes

**Files:**
- Modify: `lib/src/screens/play_hub_screen.dart`
- Test: `test/play_hub_competition_flow_test.dart`

**Interfaces:**
- Consumes: existing daily quiz, room, matchmaking, tournament, shop, and spin-wheel routes.
- Produces: a clear mode hierarchy where quick play is first, rooms are second, and advanced competition/support tools are secondary.

- [ ] **Step 1: Write failing tests** asserting `Hızlı Yarış` is the first primary action and that `Oda Kur`, `Kodla Katıl`, `1’e 1`, and `Turnuva` remain reachable.
- [ ] **Step 2: Run the tests and verify the current ordering fails.**
- [ ] **Step 3: Group existing actions** into `Tek başına`, `Arkadaşlarla`, and `Rekabet` sections; do not create new backend modes.
- [ ] **Step 4: Keep shop, joker, and spin actions in a compact support row** rather than hero cards.
- [ ] **Step 5: Run the targeted tests and verify all modes remain reachable.**

### Task 4: Make quiz results competition-only

**Files:**
- Modify: `lib/src/screens/quiz_result_screen.dart`
- Modify: `lib/src/screens/contest_screen.dart` only if it shares the result action widget
- Test: `test/quiz_result_navigation_test.dart`

**Interfaces:**
- Consumes: score, streak, room, opponent, and existing result navigation callbacks.
- Produces: result actions limited to replay, next competition, category choice, and home/profile return.

- [ ] **Step 1: Write a failing test** asserting that quiz results contain `Tekrar yarış` and `Ana sayfaya dön` but do not contain an automatic learning CTA.
- [ ] **Step 2: Run the test and verify the current result flow fails** if any learning suggestion is present.
- [ ] **Step 3: Remove only cross-mode learning prompts**; preserve explanations, wrong-answer review, favorites, reports, rewards, and replay.
- [ ] **Step 4: Run the targeted test and verify it passes.**

### Task 5: Put profile settings in the first viewport

**Files:**
- Modify: `lib/src/screens/profile_screen.dart`
- Test: `test/profile_settings_access_test.dart`

**Interfaces:**
- Consumes: existing profile, settings, avatar, shop, favorites, achievements, and mastery actions.
- Produces: a fixed top profile action for settings and a shorter, grouped profile layout.

- [ ] **Step 1: Write a failing widget test** that finds a visible settings control from the profile header without scrolling.
- [ ] **Step 2: Run the test and verify it fails** because settings currently appear deep in the profile content.
- [ ] **Step 3: Add a header settings action** with `ValueKey('profile-settings-button')` and route it to `SettingsScreen`.
- [ ] **Step 4: Group profile content** into overview, progress, saved questions, and support sections; preserve all existing actions.
- [ ] **Step 5: Run the targeted test and verify it passes on a narrow viewport.**

### Task 6: Keep learning visible but calm

**Files:**
- Modify: `lib/src/screens/learning_screen.dart` only if entry copy/layout needs alignment
- Modify: `lib/src/screens/home_screen.dart`
- Modify: `lib/src/config/subcategory_config.dart` only for existing learning labels if needed
- Test: `test/learning_entry_test.dart`

**Interfaces:**
- Consumes: existing learning lessons and subcategory configuration.
- Produces: an optional, medium-weight learning entry with a single linear path and no post-quiz interruption.

- [ ] **Step 1: Write failing tests** asserting the home learning card is reachable and that quiz result navigation does not push `LearningScreen`.
- [ ] **Step 2: Run tests and verify the forced/ambiguous behavior fails.**
- [ ] **Step 3: Keep the existing lesson engine but expose one compact path label** such as `Kelimeler → Cümleler → Dilbilgisi → Okuma → Ustalık`.
- [ ] **Step 4: Ensure the learning screen has one next action** and does not require simultaneous category, level, subcategory, and difficulty choices before starting.
- [ ] **Step 5: Run targeted tests and verify the learning path remains optional.**

### Task 7: Full verification and web smoke

**Files:**
- Modify: only files required by failing tests or analyzer output
- Test: existing relevant tests plus new targeted tests above

**Interfaces:**
- Consumes: all completed UI changes.
- Produces: verified local build and live web smoke evidence.

- [ ] **Step 1: Run `dart analyze` from `C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile` and require `No issues found!`.
- [ ] **Step 2: Run targeted Flutter tests for shell, home, play hub, quiz result, profile settings, learning entry, and category visuals.
- [ ] **Step 3: Run the complete Flutter test suite if targeted tests are green.
- [ ] **Step 4: Build Flutter web release with the production Supabase defines and verify `build/web/.htaccess` exists.
- [ ] **Step 5: Run Playwright against the live site at `https://www.zankurd.com`, inspect the first viewport, and verify no new console errors or failed app-shell requests.
- [ ] **Step 6: Compare local and live `main.dart.js` SHA256 hashes before claiming deployment complete.**
