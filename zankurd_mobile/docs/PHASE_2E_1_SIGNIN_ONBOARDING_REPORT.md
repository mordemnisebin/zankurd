# Phase 2E-1 — Sign In & Onboarding Redesign Report

**Date:** 2026-07-08  
**Branch:** `ui-quality-merge`  
**Commit:** `3ff754a` — `phase 2e-1: redesign sign in and onboarding screens`  
**Scope:** UI-only redesign of authentication entry and first-launch onboarding screens

---

## Exact Files Inspected

| File | Purpose |
|------|---------|
| `lib/src/screens/sign_in_screen.dart` | Sign-in UI, auth actions, layout |
| `lib/src/screens/onboarding_screen.dart` | First-launch onboarding flow |
| `lib/src/providers/auth_provider.dart` | Auth behavior reference (not modified) |
| `lib/src/widgets/styled_button.dart` | `GeometricGradientButton` (coral CTA) |
| `lib/src/widgets/styled_input.dart` | Form inputs (not modified) |
| `lib/src/widgets/kilim_pattern_painter.dart` | Hero pattern reference |
| `lib/src/theme/app_theme.dart` | Design tokens |
| `lib/src/screens/app_shell.dart` | Onboarding gate reference (not modified) |
| `test/widget_test.dart` | Auth/onboarding widget tests |
| `docs/SPIN_WHEEL_FULL_AUDIT.md` | Context (spin wheel explicitly out of scope) |

---

## Exact Files Changed

| File | Lines changed (approx.) |
|------|-------------------------|
| `lib/src/screens/sign_in_screen.dart` | +204 / −198 (net visual restructure) |
| `lib/src/screens/onboarding_screen.dart` | included in commit |

**No other files modified.** Spin wheel, repository, SQL, routes, providers, and unrelated screens were not touched.

---

## What Was Changed Per File

### `sign_in_screen.dart`

**Added:**
- Import `kilim_pattern_painter.dart`
- `_SignInHeroBanner` — kilim-pattern hero card with `secondaryAccent → bgDeep` gradient, gold glow, welcome title/subtitle using `AppTypography`
- `_AuthFormPanel` — subtle glass panel wrapping social login, divider, email/password form, CTA, and sign-up link

**Updated:**
- Removed octagon/diamond `geometric_shapes` background overlays (kept soft radial gold/green glows + `darkAuthGradient`)
- Narrow (mobile) layout: logo → kilim hero banner → form panel containing all auth actions
- Wide (landscape/tablet) layout: left column logo + kilim hero banner; right column form panel
- Spacing migrated to `AppSpacing` tokens in scroll frame and key vertical gaps
- `_AuthScrollFrame` horizontal/bottom padding uses `AppSpacing.md` / `AppSpacing.lg`

**Preserved unchanged:**
- All auth methods: `_signIn`, `_signInWithGoogle`, `_signInAsGuest`, `_resetPassword`
- `AuthProvider` calls: `signInWithEmail`, `signInWithGoogle`, `signInAsGuest`, `resetPassword`
- Form validation rules and error messages
- `LoadingOverlay` usage
- Navigation to `SignUpScreen` via `AppRoute.to`
- `_GoogleSignInButton`, `_GuestSignInButton`, `_LanguageToggle` behavior and copy
- `GeometricGradientButton` coral CTA for "Giriş Yap"
- `Theme(data: AppTheme.dark())` auth shell
- All bilingual strings (KU/TR)

### `onboarding_screen.dart`

**Added:**
- Import `kilim_pattern_painter.dart`

**Updated:**
- Page hero blocks: institutional `secondaryAccent → bgDeep` gradient + subtle kilim pattern (opacity 0.05)
- Hero icons: circular treatment with accent/gold glow; gold icon only on rewards page (`AppTheme.gold`)
- Section titles: 4px accent gradient bar + `AppTypography.heading1`
- Body and bullet text: `AppTypography.bodyMedium` / `AppTypography.caption`
- Spacing: `AppSpacing.page`, `.xl`, `.xs`, `.sm`, `.md`, `.lg`, `.cardGap`
- Page indicator dot margins tokenized
- `AppRadius.card` on hero containers
- Skip button ("Atla") uses `AppTypography.caption`

**Preserved unchanged:**
- `onComplete` callback wiring
- `PageController` navigation ("Sonraki" / "Başla")
- Skip ("Atla") behavior
- Three onboarding pages content (titles, bodies, bullets)
- `GeometricGradientButton` coral CTA
- `AppTheme.backgroundGradient(context)` scaffold (light/dark aware)
- Brand lockup animation (`_AnimatedBrandLockup`)

---

## What Was NOT Changed

- `spin_wheel_screen.dart` and all spin wheel logic
- Repository layer (`supabase_zankurd_repository.dart`, `mock_zankurd_repository.dart`)
- `AuthProvider` implementation
- Supabase auth logic
- Profile creation logic
- Onboarding completion storage key (`zankurd.onboarding.seen`)
- Route names and `AppRoute` navigation targets
- `sign_up_screen.dart`
- `app_shell.dart` onboarding gate logic
- SQL / SharedPreferences keys (except those referenced but not edited)
- Coin, leaderboard, tournament, room, matchmaking logic
- New packages added: **none**

---

## Change Classification

| File | Classification |
|------|----------------|
| `sign_in_screen.dart` | **UI-only** + minor safe layout refactor (extracted `_SignInHeroBanner`, `_AuthFormPanel` widgets; removed decorative geometric overlays) |
| `onboarding_screen.dart` | **UI-only** |

**No logic-related changes.** Zero modifications to auth provider calls, validators, storage, or navigation behavior.

---

## Auth / Navigation / Onboarding Logic Preservation

| Behavior | Preserved? |
|----------|------------|
| Email/password sign-in flow | ✅ |
| Google sign-in flow | ✅ |
| Guest sign-in flow | ✅ |
| Password reset flow | ✅ |
| Sign-up navigation | ✅ |
| Language toggle (KU/TR) | ✅ |
| Loading state disables buttons | ✅ |
| Onboarding skip sets `zankurd.onboarding.seen` | ✅ (via existing `app_shell` — not modified) |
| Onboarding page swipe + CTA progression | ✅ |
| First-launch shows onboarding before auth | ✅ (test verified) |

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
Final line: All tests passed!
```

**Auth/onboarding tests passing (non-exhaustive):**
- `auth alternative buttons stay readable on their own backgrounds`
- `auth alternative buttons ignore taps while loading`
- `auth form text stays readable on the dark auth background`
- `guest sign in is reachable in the first mobile auth viewport`
- `first launch shows onboarding before auth screen`
- `onboarding fits a landscape phone viewport`
- `onboarding fits a portrait phone viewport`
- `onboarding fits a tablet and web viewport`

### Preview / Screenshot Tests

**No preview tests exist** for `sign_in_screen.dart` or `onboarding_screen.dart`.

Existing preview tests (not run in main suite) cover: home, categories, quiz, profile, result, quickplay, design tokens — none include sign-in or onboarding.

---

## Risk Assessment

| Area | Risk | Notes |
|------|------|-------|
| Auth logic regression | **Very Low** | No provider/repository changes |
| Navigation regression | **Very Low** | Same routes and callbacks |
| Visual regression | **Low** | Layout restructured; scroll view preserves small-screen access |
| Test breakage | **Very Low** | All 335 tests pass including auth contrast/readability checks |
| Light/dark onboarding | **Low** | Theme-aware tokens retained |
| Wide/landscape auth | **Low** | Wide layout preserved with form panel |
| Performance | **Very Low** | Kilim pattern only in hero areas, `IgnorePointer` |

**Overall:** **Safe** — narrow UI-only scope, full test suite green.

---

## Manual Visual Test Checklist

| # | Screen | Check |
|---|--------|-------|
| 1 | Sign-in (390×844) | Kilim hero banner readable; guest button visible without scroll |
| 2 | Sign-in (844×390) | Wide split layout: logo+hero left, form panel right |
| 3 | Sign-in | Google button white bg + dark text; guest button white text on glass panel |
| 4 | Sign-in | Email/password fields readable; coral "Giriş Yap" CTA prominent |
| 5 | Sign-in | Language toggle KU/TR switches copy |
| 6 | Sign-in | "Kaydol" navigates to sign-up |
| 7 | Onboarding (390×844) | Three pages swipe; kilim hero + icon visible; no overflow |
| 8 | Onboarding (844×390) | Landscape: "Sonraki" button within viewport |
| 9 | Onboarding (1200×800) | Tablet: logo + CTA aligned |
| 10 | Onboarding | Gold accent only on page 3 daily rewards icon |
| 11 | Onboarding | "Atla" skips to sign-in; "Başla" on last page completes |
| 12 | Light mode | Onboarding readable with light `backgroundGradient` |
| 13 | Dark mode | Sign-in dark auth gradient + hero contrast |

---

## Design Direction Applied

| Element | Implementation |
|---------|----------------|
| Dark matte anthracite base | `AppTheme.darkAuthGradient` (sign-in), `backgroundGradient` (onboarding) |
| Deep green institutional gradient | `secondaryAccent → bgDeep` kilim hero cards |
| Coral CTA | Existing `GeometricGradientButton` (`AppTheme.accentGradient`) |
| Gold accents | Subtle hero glow only; gold icon on onboarding rewards page |
| Kilim pattern | Hero/header areas only, opacity 0.05 |
| Tokens | `AppSpacing`, `AppTypography`, `AppRadius`, `AppTheme.glowShadow` |

---

## Next Recommended Step

1. **Manual visual pass** on sign-in and onboarding using checklist above (especially 390×844 guest button reachability on device).
2. **Optional:** Add simple `signin_onboarding_preview_test.dart` with `--tags preview` if screenshot regression desired (not required for Phase 2E-2).
3. **Proceed to Phase 2E-2** — next screen group per UI roadmap (e.g., `sign_up_screen.dart`, `room_screen.dart`, or `learning_screen.dart` per plan — confirm with roadmap; **do not start room/learning unless explicitly scoped**).

---

*End of Phase 2E-1 report.*