# ZanKurd Design Grammar Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ZanKurd'un mevcut iş mantığını değiştirmeden Home–Play–Learning–Profile–Leaderboard–Shop–Result hattını tek, sakin ve premium bir görsel gramerde birleştirmek.

**Architecture:** Mevcut `AppTheme`, `AppPanel`, `ModeCard`, `AppRowCard` ve `ScreenIdentityHeader` korunacak; yeni ekran-özel dekorlar eklemek yerine ortak bileşenler sadeleştirilecek. Her görsel davranış değişikliği önce widget testiyle RED olarak kanıtlanacak, sonra minimum üretim değişikliğiyle GREEN yapılacak. Üretim Supabase, auth backend, quiz ödül/settlement, rota mimarisi ve release süreçleri kapsam dışıdır.

**Tech Stack:** Flutter/Dart, flutter_test, Provider, mevcut ZanKurd AppTheme tasarım sistemi.

**Spec:** 2026-09-10 bütün-uygulama ilk-kullanıcı tasarım denetimi ve kullanıcı onayı (bu sohbet).

## Global Constraints

- Yalnız `/Users/kocer/Projects/zankurd` içinde çalış.
- Mevcut kullanıcı değişikliklerini reset/stash/silme veya ezme.
- Kurmancî karakterleri (`ê î û ş ç`) ve doğal metin akışını koru.
- Production Supabase, migration push/repair, deploy, release ve git push yapma.
- İş mantığını değiştirme; bu tur UI kompozisyonu, görsel hiyerarşi, responsive metin ve ortak bileşenlerle sınırlı.
- Her üretim değişikliğinden önce ilgili test RED olmalı; ardından hedef test GREEN olmalı.
- Son turda `dart format`, `dart analyze`, hedef testler, tam `flutter test` ve gerçek screen-tour render/visual QA çalıştır.

---

### Task 1: Quiet shared identity header

**Files:**
- Modify: `lib/src/widgets/screen_identity_header.dart`
- Test: `test/visual_polish_widgets_test.dart`

**Interfaces:**
- Consumes: mevcut `AppTheme`, `AppTypography`, `AppSpacing`.
- Produces: `ScreenIdentityHeader` aynı constructor API'sini korur; tam renkli panel yerine sakin tonal yüzey, küçük accent işareti ve Kurmancî-safe wrap sağlar.

- [ ] **Step 1: Write the failing tests**
  - Kimlik başlığının büyük gradient yüzey kullanmadığını, accent'i yalnız küçük işarette tuttuğunu doğrula.
  - Uzun Kurmancî başlığın tek satır ellipsis'e zorlanmadığını doğrula.
- [ ] **Step 2: Run `flutter test test/visual_polish_widgets_test.dart` and verify RED.**
- [ ] **Step 3: Implement the minimal neutral/tonal header and wrap behavior.**
- [ ] **Step 4: Re-run the test and verify GREEN.**

### Task 2: Shared section-heading grammar

**Files:**
- Modify: `lib/src/widgets/screen_identity_header.dart`
- Modify: `lib/src/screens/play_hub_screen.dart`
- Modify: `lib/src/screens/learning_screen.dart`
- Test: `test/visual_polish_widgets_test.dart`
- Test: `test/play_hub_screen_test.dart`
- Test: `test/learning_screen_test.dart`

**Interfaces:**
- Produces: `ScreenSectionHeading(title:, subtitle:, trailing:)`, a card-free section heading with consistent typography and spacing.

- [ ] **Step 1: Add a failing widget test for `ScreenSectionHeading`.**
- [ ] **Step 2: Verify RED because the widget does not exist.**
- [ ] **Step 3: Implement the widget and replace `_PlaySectionHeading` / `_LearningSectionHeading`.**
- [ ] **Step 4: Run the three targeted test files and verify GREEN.**

### Task 3: Play semantic color roles

**Files:**
- Modify: `lib/src/screens/play_hub_screen.dart`
- Test: `test/home_play_hierarchy_test.dart`

**Interfaces:**
- Secondary social/navigation modes use `AppTheme.brand`; event/prestige modes use `AppTheme.gold`; Quick Duel keeps its high-energy hero identity and the one primary CTA.

- [ ] **Step 1: Add failing expectations for the ModeCard accent roles.**
- [ ] **Step 2: Verify RED against current sapphire/teal/saffron/purple accents.**
- [ ] **Step 3: Replace only the secondary/event accent assignments.**
- [ ] **Step 4: Run `test/home_play_hierarchy_test.dart` and `test/play_hub_screen_test.dart`; verify GREEN.**

### Task 4: Kurmancî-safe card text

**Files:**
- Modify: `lib/src/widgets/mode_card.dart`
- Modify: `lib/src/widgets/app_row_card.dart`
- Test: `test/visual_polish_widgets_test.dart`
- Test: `test/home_play_hierarchy_test.dart`

**Interfaces:**
- Titles and supporting text may wrap to two lines on narrow devices/text scaling instead of being forced into one-line ellipsis.

- [ ] **Step 1: Add failing long-Kurmancî/text-scale widget tests.**
- [ ] **Step 2: Verify RED on current `maxLines: 1` contracts.**
- [ ] **Step 3: Allow two-line title/supporting copy while preserving >=48dp targets.**
- [ ] **Step 4: Run targeted tests and verify GREEN/no overflow.**

### Task 5: Calm the Shop surface hierarchy

**Files:**
- Modify: `lib/src/screens/shop_screen.dart`
- Test: `test/shop_screen_test.dart`

**Interfaces:**
- Item-specific `themeColor` remains an emblem/icon identity only; large card surface, border, shadow and bottom stripe do not turn the grid into a rainbow. Gold represents featured/prestige; coral remains purchase CTA.

- [ ] **Step 1: Add failing widget contracts for neutral hero/grid surfaces.**
- [ ] **Step 2: Verify RED.**
- [ ] **Step 3: Neutralize large product surfaces and remove decorative hue stripe; preserve purchase behavior.**
- [ ] **Step 4: Run `test/shop_screen_test.dart` and verify GREEN.**

### Task 6: Profile and Leaderboard page-heading convergence

**Files:**
- Modify: `lib/src/screens/profile_screen.dart`
- Modify: `lib/src/screens/leaderboard_screen.dart`
- Reuse: `lib/src/widgets/screen_identity_header.dart`
- Test: relevant profile and leaderboard widget tests.

**Interfaces:**
- Page title remains visible and accessible, but custom accent-bar header variants converge on the shared quiet heading grammar; leaderboard actions remain reachable.

- [ ] **Step 1: Add failing hierarchy/responsive tests for shared heading use.**
- [ ] **Step 2: Verify RED.**
- [ ] **Step 3: Replace only ad-hoc header composition; retain data/actions/navigation.**
- [ ] **Step 4: Run profile/leaderboard targeted tests and verify GREEN.**

### Task 7: Cross-review and visual verification

**Files:**
- No business-logic changes unless a verified UI regression requires a TDD fix.

- [ ] **Step 1: Run `dart format` on changed Dart files.**
- [ ] **Step 2: Run `dart analyze`.**
- [ ] **Step 3: Run all targeted tests from Tasks 1–6.**
- [ ] **Step 4: Run full `flutter test`.**
- [ ] **Step 5: Render the screen tour for phone/wide, light/dark and TR/KU where supported; visually inspect real output.**
- [ ] **Step 6: Ask Cursor and OpenCode for independent read-only review of the final UI diff.**
- [ ] **Step 7: If a real issue is found, add a failing regression test before the fix and repeat verification.**
