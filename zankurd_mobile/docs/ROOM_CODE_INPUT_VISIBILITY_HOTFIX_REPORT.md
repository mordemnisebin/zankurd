# Room Code Input Visibility Hotfix Report

**Date:** 2026-07-09  
**Branch:** `ui-quality-merge`  
**Commit:** `0eab7ec` — `fix: improve room code input readability`  
**Prior docs checkpoint:** `18fffd1`  
**Audit reference:** `docs/PHASE_2E_3A_ROOM_FLOW_MAPPING_AUDIT.md`

---

## Exact Files Inspected

| File | Purpose |
|------|---------|
| `lib/src/screens/home_screen.dart` | `_showJoinSheet` join bottom sheet |
| `lib/src/widgets/styled_input.dart` | Phase 2E input pattern reference |
| `lib/src/theme/app_theme.dart` | `AppTheme`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppColors` |
| `lib/src/screens/sign_in_screen.dart` | Auth input styling reference |
| `lib/src/screens/sign_up_screen.dart` | Auth form panel reference |
| `test/widget_test.dart` | Existing join-sheet and validation tests |

---

## Exact Files Changed

| File | Change |
|------|--------|
| `lib/src/screens/home_screen.dart` | Join sheet input visibility + token alignment |
| `test/widget_test.dart` | Field presence assertion + typed-code test |

**No other files modified.**

---

## What Was Changed

### `home_screen.dart` — `_showJoinSheet`

| Area | Before | After |
|------|--------|-------|
| Title | Raw `TextStyle` 22/w800 | `AppTypography.heading1` + `textPrimaryColor` |
| Field label | Floating `labelText` inside `InputDecoration` | External label `Text` (matches `StyledInputField` pattern) |
| Typed text | `textPrimaryColor`, w700, no size token | `AppTypography.bodyLarge`, w700, `letterSpacing: 0.6` |
| Hint | `textMutedColor` (low contrast on green fill) | `textSubColor` via `AppTypography.bodyLarge` |
| Fill | Implicit theme merge only | Explicit `filled: true`, `fillColor: surfaceHiColor(context)` |
| Cursor | `AppTheme.accent` | `AppColors.focus` |
| Borders | enabled + focused only | enabled, focused, `errorBorder`, `focusedErrorBorder` |
| Prefix | none | `Icons.tag_rounded` with `textSubColor` |
| Error text | default theme | Explicit `AppTheme.wrong`, 12px, w600 |
| Spacing/padding | hardcoded `20` / `14` | `AppSpacing.md`, `sm`, `xs`; `AppRadius.sm` |
| Test hook | none | `ValueKey('join-room-code-field')` |

**Preserved unchanged:**
- `textCapitalization: TextCapitalization.characters`
- Empty-code validator strings and logic
- `joinOnlineRoom` call, error handling, navigation
- Bottom sheet shape, `isScrollControlled`, controller dispose

### `widget_test.dart`

| Test | Change |
|------|--------|
| `join by code opens the room code sheet from the hero` | Added `join-room-code-field` key assertion |
| `join room sheet accepts typed room code text` | **New** — opens sheet, types `ZK-ABCD`, verifies visible text |

---

## What Was Not Changed

| Area | Status |
|------|--------|
| Room creation (`createOnlineRoom`) | Untouched |
| Join repository logic (`joinOnlineRoom`) | Untouched |
| Realtime / participant sync | Untouched |
| Start button / `startGame` | Untouched |
| Supabase RPCs / SQL | Untouched |
| Navigation routes | Untouched |
| Matchmaking / quiz start flow | Untouched |
| `styled_input.dart` | Read only — no edits |
| `app_theme.dart` | Read only — no edits |

---

## Confirmations

| Check | Result |
|-------|--------|
| UI-only hotfix | **Yes** — visual/input decoration changes in `_showJoinSheet` only |
| Room/realtime/start logic untouched | **Yes** |
| Validator behavior preserved | **Yes** — same empty-string messages |
| Uppercase capitalization preserved | **Yes** |

---

## Verification

### `dart analyze`

**Exit 0** — 10 info (`avoid_print` in preview test files); `lib/` clean.

### `flutter test --exclude-tags preview`

**Exit 0** — **336 / 336 passed** (was 335; +1 new test)

| Room-code tests | Result |
|-----------------|--------|
| `join by code opens the room code sheet from the hero` | Pass |
| `join room sheet accepts typed room code text` | Pass |
| `empty room code is validated locally before online join` | Pass |

---

## Tests Added / Updated

| Action | Test |
|--------|------|
| Updated | `join by code opens the room code sheet from the hero` |
| Added | `join room sheet accepts typed room code text` |

---

## Manual Visual Test Checklist

| # | Scenario | Check |
|---|----------|-------|
| 1 | Dark mode — open join sheet | Title, label, hint `ZK-XXXX` readable on elevated fill |
| 2 | Dark mode — type `ZK-ABCD` | Typed characters high contrast vs fill |
| 3 | Light mode — open join sheet | Same readability on white/cream surfaces |
| 4 | Focus field | Coral/green focus border visible (`AppColors.focus`) |
| 5 | Tap Katıl with empty field | Red error border + `Oda kodu gerekli.` |
| 6 | Cursor | Visible while editing |
| 7 | Prefix tag icon | Visible, secondary tone |
| 8 | Katıl CTA | Unchanged, still readable |

---

## Risk Assessment

| Risk | Level | Notes |
|------|-------|-------|
| Visual regression on join sheet | Low | Scoped to one bottom sheet |
| Test breakage | Very Low | 336/336 green |
| Logic regression | Very Low | No repository/navigation edits |
| Light/dark contrast edge cases | Low | Uses theme-aware token helpers |
| KU locale label | Low | External label preserves KU/TR strings |

**Overall:** **Low risk** — narrow UI-only hotfix.

---

## Next Recommended Step

1. **Manual device check** on dark + light themes (checklist above).
2. **Proceed to Phase 2E-3B sync hardening** per `PHASE_2E_3A` — verify Supabase realtime publication + RLS for host/guest visibility (separate from this UI fix).
3. **Optional:** Full room lobby visual redesign (kilim hero) as a later Phase 2E-3C pass.

---

*End of room code input visibility hotfix report.*