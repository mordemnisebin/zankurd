# Competition-first UX Implementation Plan

**Goal:** Make the competition-first ZanKurd flow immediately understandable while giving learning, review, and daily competition one clear next action.

**Architecture:** Keep the existing screen architecture and repository contracts. Add small presentation widgets and stable keys, reuse existing `ReviewScreen`, `ContestScreen`, and lesson navigation, and avoid broad refactors.

**Tech Stack:** Flutter/Dart, existing Provider state, widget tests, `dart analyze`, Flutter web release build.

## Global Constraints

- Turkish copy and Kurmancî copy must remain paired and natural.
- Touch targets remain at least 44 px high.
- Existing user changes and uncommitted content files must be preserved.
- Each behavior change receives a failing widget/source assertion before implementation.
- No Git/GitHub MCP, commit, reset, or destructive cleanup.

### Task 1: Result actions

**Files:**
- Modify: `lib/src/screens/quiz_result_screen.dart`
- Test: `test/quiz_result_screen_test.dart`

- [ ] Add assertions for `result-review-wrong-button`, a 44 px action height, and the user-facing label.
- [ ] Run the focused test and confirm it fails because the new action is absent.
- [ ] Add a wrong-answer-only route using the existing `ReviewScreen` and preserve the existing full review route.
- [ ] Run the focused test and confirm it passes.

### Task 2: Learning next step

**Files:**
- Modify: `lib/src/screens/learning_screen.dart`
- Test: `test/learning_screen_test.dart`

- [ ] Assert that a loaded category exposes one stable `learning-next-step` action.
- [ ] Run the focused test and confirm it fails.
- [ ] Add a compact next-step card that opens the first incomplete lesson and uses `Devam et`/`Bidomîne` copy.
- [ ] Run learning tests and confirm they pass.

### Task 3: Daily competition entry

**Files:**
- Create: `lib/src/screens/home/daily_race_card.dart`
- Modify: `lib/src/screens/home_screen.dart`
- Test: `test/kulturel_modern_home_test.dart`

- [ ] Assert that Home shows `home-daily-race-entry` and `Günlük yarış`.
- [ ] Run the focused test and confirm it fails.
- [ ] Add a compact race card that navigates directly to `ContestScreen`.
- [ ] Run Home tests and confirm they pass.

### Task 4: Verification

- [ ] Run `dart analyze`.
- [ ] Run the full Flutter test suite.
- [ ] Build Flutter web release from the ASCII validation copy.
- [ ] Inspect the live/local web shell and verify the generated build hash if deployment is in scope.
