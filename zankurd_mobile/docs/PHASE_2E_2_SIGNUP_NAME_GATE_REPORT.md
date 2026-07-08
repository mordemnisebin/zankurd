# Phase 2E-2 — Sign Up & Profile Name Gate Redesign Report

**Date:** 2026-07-08  
**Branch:** `ui-quality-merge`  
**Commit:** `6755744` — `phase 2e-2: redesign sign up and profile name gate screens`  
**Prior context:** Phase 2E-1 @ `3ff754a` (sign-in + onboarding redesign)

---

## Exact Files Inspected

| File | Purpose |
|------|---------|
| `lib/src/screens/sign_up_screen.dart` | Multi-step registration UI |
| `lib/src/screens/profile_name_gate_screen.dart` | First profile name capture gate |
| `lib/src/screens/sign_in_screen.dart` | Visual reference (not modified) |
| `lib/src/providers/auth_provider.dart` | Auth behavior reference (not modified) |
| `lib/src/widgets/styled_button.dart` | `GeometricGradientButton` coral CTA |
| `lib/src/widgets/styled_input.dart` | Form inputs (not modified) |
| `lib/src/widgets/kilim_pattern_painter.dart` | Hero pattern |
| `lib/src/widgets/app_logo.dart` | Brand logo |
| `lib/src/theme/app_theme.dart` | Design tokens |
| `test/widget_test.dart` | Auth + profile name gate tests |
| `docs/PHASE_2E_1_SIGNIN_ONBOARDING_REPORT.md` | Prior phase reference |

---

## Exact Files Changed

| File | Diff |
|------|------|
| `lib/src/screens/sign_up_screen.dart` | Visual restructure + token migration |
| `lib/src/screens/profile_name_gate_screen.dart` | Full visual modernization |

**No other files modified.**

---

## What Was Changed Per File

### `sign_up_screen.dart`

**Added:**
- Import `kilim_pattern_painter.dart` (replaced `geometric_shapes.dart`)
- `_SignUpHeroBanner` — kilim-pattern hero with `secondaryAccent → bgDeep` gradient, step-aware subtitle
- `_AuthFormPanel` — glass panel matching Phase 2E-1 sign-in form container

**Updated:**
- Wrapped scaffold in `Theme(data: AppTheme.dark())` for consistent auth shell
- Removed octagon/diamond geometric background overlays (kept soft radial glows + `darkAuthGradient`)
- Progress indicator → kilim hero banner → form panel layout hierarchy
- Step form content, navigation buttons, and sign-in link grouped inside `_AuthFormPanel`
- Removed redundant inner card wrapper from `_buildStepContent` (panel provides container)
- Spacing migrated to `AppSpacing` tokens
- `_ReviewItem` labels use `AppTypography.caption`
- `_AuthScrollFrame` padding uses `AppSpacing.md` / `AppSpacing.lg`

**Preserved unchanged:**
- 3-step wizard logic (`_currentStep`, `_nextStep`, `_previousStep`)
- All step validators and error messages
- `_signUp()` → `authProvider.signUpWithEmail()`
- `LoadingOverlay` usage
- Email confirmation snackbar flow
- `Navigator.pop()` on success and sign-in link
- `GeometricGradientButton` coral CTA ("İleri" / "Hesap Oluştur")
- All bilingual strings (KU/TR)
- Progress step indicator (3 numbered pills)

### `profile_name_gate_screen.dart`

**Added:**
- Imports: `app_logo.dart`, `kilim_pattern_painter.dart`, `styled_button.dart`
- `LayoutBuilder` with compact mode (`maxHeight < 860`) for small-screen overflow prevention

**Updated:**
- Hero area: institutional `secondaryAccent → bgDeep` gradient + kilim pattern (opacity 0.05)
- Replaced raw `Image.asset` logo with `AppLogo(onCard: true)`
- Hero value rows: gold accent only on rewards row (`AppTheme.gold`); coral on streak row
- Form area: `AppTheme.backgroundGradient(context)` — light/dark aware
- Form wrapped in elevated card with `AppTheme.softShadow`, accent bar + `AppTypography.heading2` title
- CTA: `GeometricGradientButton` coral gradient (replaces `FilledButton.icon`) with loading state
- Spacing/typography: `AppSpacing`, `AppTypography` throughout
- Compact layout: smaller logo/title, hides third value row, adjusted flex ratio (42/58)

**Preserved unchanged:**
- `_save()` → `repository.updateProfileName(name)` → `onCompleted()`
- `ValueKey('player-name-field')` on text field
- Validator rules (min 2, max 24 characters) and error messages
- `_isDefaultName()` logic for initial name
- Error snackbar on save failure
- `ErrorReporter.record()` on catch
- All bilingual strings (KU/TR)

---

## What Was NOT Changed

- `sign_in_screen.dart` — not touched
- `onboarding_screen.dart` — not touched
- `spin_wheel_screen.dart` — not touched
- `AuthProvider` implementation and Supabase auth logic
- Repository/provider logic
- Storage keys (`zankurd.onboarding.seen`, `zankurd.profileName.completed`, etc.)
- Navigation routes and callbacks (`onCompleted`, `Navigator.pop`)
- Room, matchmaking, leaderboard, tournament, coin, quiz, learning logic
- New packages: **none**

---

## Change Classification

| File | Classification |
|------|----------------|
| `sign_up_screen.dart` | **UI-only** + minor safe layout refactor (extracted hero/panel widgets, removed decorative overlays) |
| `profile_name_gate_screen.dart` | **UI-only** + minor safe layout refactor (compact mode for overflow, widget extraction) |

**No logic-related changes.**

---

## Auth / Profile / Navigation / Onboarding Logic Preservation

| Behavior | Preserved? |
|----------|------------|
| Sign-up 3-step validation | ✅ |
| `signUpWithEmail` with displayName | ✅ |
| Email confirmation flow | ✅ |
| Sign-in link pop navigation | ✅ |
| Profile name `updateProfileName` | ✅ |
| Name gate `onCompleted` callback | ✅ |
| Default name detection | ✅ |
| Field validators (2–24 chars) | ✅ |
| `auth requires player name before home` test flow | ✅ |
| Onboarding gate (unchanged, upstream) | ✅ |

---

## Verification Results

### `dart analyze`

```
Exit code: 0
Errors: 0
Warnings: 0
Info: 10 (avoid_print in preview test files only)
lib/: clean
```

### `flutter test --exclude-tags preview`

```
335 / 335 passed
Exit code: 0
```

**Key tests verified:**
- `auth requires player name before home` — passed (overflow fixed via compact layout)
- `auth alternative buttons stay readable on their own backgrounds` — unaffected (sign-in)
- `auth form text stays readable on the dark auth background` — unaffected (sign-in)
- `guest sign in is reachable in the first mobile auth viewport` — unaffected (sign-in)
- `first launch shows onboarding before auth screen` — unaffected (onboarding)

### Preview / Screenshot Tests

**No preview tests exist** for `sign_up_screen.dart` or `profile_name_gate_screen.dart`.

Existing preview tests cover: home, categories, quiz, profile, result, quickplay, design tokens — none include sign-up or profile name gate.

---

## Risk Assessment

| Area | Risk | Notes |
|------|------|-------|
| Sign-up logic regression | **Very Low** | No provider/validator changes |
| Profile name gate regression | **Very Low** | Same repository call + validators |
| Small-screen overflow | **Low** | Fixed during implementation; compact mode at `<860px` height |
| Light/dark readability | **Low** | Profile gate form uses theme-aware tokens |
| Test breakage | **Very Low** | Full suite green after overflow fix |
| Visual inconsistency with 2E-1 | **Very Low** | Matching kilim hero + glass panel patterns |

**Overall:** **Safe** — narrow UI-only scope, all tests passing.

---

## Manual Visual Test Checklist

| # | Screen | Check |
|---|--------|-------|
| 1 | Sign-up step 1 (390×844) | Kilim hero shows step subtitle; email/password fields in glass panel |
| 2 | Sign-up step 2 | Username field; "Geri" + coral "İleri" buttons |
| 3 | Sign-up step 3 | Review items readable; coral "Hesap Oluştur" CTA |
| 4 | Sign-up | Progress pills highlight current step (coral gradient) |
| 5 | Sign-up | "Giriş Yap" link pops back to sign-in |
| 6 | Profile name gate (390×844) | No overflow; hero + form fit viewport |
| 7 | Profile name gate | Kilim hero, AppLogo, gold rewards row accent |
| 8 | Profile name gate | Form card readable in light and dark mode |
| 9 | Profile name gate | Enter name → coral "Oyuna Başla" → reaches home |
| 10 | Profile name gate | Validation: <2 chars shows error |
| 11 | Sign-up (844×390) | Scrollable; no clipped content in landscape |
| 12 | Profile name gate (compact) | Third value row hidden; layout still balanced |

---

## Design Direction Applied

| Element | Implementation |
|---------|----------------|
| Dark matte anthracite base | `AppTheme.darkAuthGradient` (sign-up), `backgroundGradient` (name gate form) |
| Deep green institutional hero | `secondaryAccent → bgDeep` + kilim pattern |
| Coral CTA | `GeometricGradientButton` (`AppTheme.accentGradient`) |
| Gold accents | Subtle hero glow; gold icon on rewards value row only |
| Kilim pattern | Hero/header areas only, opacity 0.05 |
| Tokens | `AppSpacing`, `AppTypography`, `AppRadius`, `AppTheme.glowShadow/softShadow` |
| Consistency | Matches Phase 2E-1 sign-in `_SignInHeroBanner` + `_AuthFormPanel` patterns |

---

## Next Recommended Step

1. **Manual visual pass** on sign-up 3-step flow and profile name gate (checklist above).
2. **Proceed to Phase 2E-3** — next scoped screen group per UI roadmap (candidates: `sign_up_screen` related flows already done; consider `room_screen.dart` or `learning_screen.dart` only when explicitly scoped).
3. **Optional:** Add `signup_namegate_preview_test.dart` with `--tags preview` for screenshot regression (low priority).

---

*End of Phase 2E-2 report.*