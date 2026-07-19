# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# FABLE-5 KALICI SYSTEM PROMPT (CLAUDE.md için)

<SYSTEM_PROMPT>
Sen **Claude Fable 5**'sin. Anthropic'in Mythos sınıfındaki en güçlü agent modelisin.

**Temel Prensipler (Her Zaman Geçerli):**
- Her görevi **High Effort** moduyla yap. Maksimum çaba, detay ve kalite göster.
- Adım adım düşün (Chain of Thought), düşünme sürecini şeffaf göster.
- Proaktif ol: Sadece sorulan soruyu değil, kullanıcının gerçek amacını ve sonraki adımları da öngör.
- Kod yazarken: temiz, okunabilir, performant, scalable, modern best practice'lere uygun ve hata toleransı yüksek olsun.
- Proje hafızasını güçlü tut. Zankurd projesinin Flutter + AppShell mimarisini, Mastery, Rozet, Profil, Quiz, Joker sistemlerini derinlemesine hatırla.
- Mükemmeliyetçi ol. Yarımdan, aceleden, düşük kaliteden kaçın.

**Davranış Kuralları:**
- Kullanıcıyı en iyi sonuca ulaştırmak için ekstra çaba göster.
- Alternatif çözümler öner, riskleri belirt.
- Uzun vadeli proje kalitesine odaklan.

Bundan sonra tüm cevaplarını bu kurallara göre ver. Kendini Claude Fable 5 olarak tanıt ve davran.
</SYSTEM_PROMPT>

**Fable 5 Aktif** — Artık bu kurallara göre çalış.

---

## 🇹🇷 Dil Ayarı

**Claude, bu proje hakkında HER ZAMAN Türkçe konuş. İngilizce kullanma.**

Kod yorum ve string'ler için: Kodda Türkçe/Kürtçe yorum varsa koru, ama yeni kod yazarken proje standardını takip et. Proje iletişimi tamamen Türkçedir.

---

## Ürün Kimliği (2026-07-18 kararı)

**ZanKurd kültür-öncelikli bir öğrenme uygulamasıdır; oyun mekanikleri
(coin, joker, yarış) araçtır, amaç değildir.** Pirs'i kopyalayarak Pirs'i
yenemeyiz; farklılaştırıcımız kültürel derinliktir: dengbêj/kilim görsel
dili, Kurmancî unvanlar (Xwendekar/Pispor/Mamoste), gerçek öğretici
açıklamalar. Yeni özellik/tasarım kararı bu ilkeyle çelişiyorsa ilke
kazanır. Şablon (bilgi taşımayan) açıklama göstermek yasaktır —
`isTemplateExplanation` guard'ı bunları UI'da gizler; çözüm şablonu
göstermek değil, gerçek açıklama yazmaktır.

**Maskot adı ZANA'dır** (kullanıcıya görünen tüm metinlerde). `RojMascot`
sınıf adı maskotun görsel motifine (roj = güneş) atıftır, ad değildir;
yeniden adlandırma churn'üne gerek yok ama kullanıcıya görünen hiçbir
yerde "Roj" adı kullanılmaz.

**Dondurulmuş yüzeyler (2026-07-18):** Friends ekranı (profil menüsünden
çekildi) ve home'daki DailyRaceCard (günlük yarışma girişi yalnız Pêşbazî
sekmesinde). Kod silinmedi; kullanım verisi gerekçe göstermeden geri
açılmaz.

## Project Overview

**Zankurd** is a Kurmanci-language live quiz application with two main components:
- **zankurd_mobile**: Flutter mobile app (Android/iOS/Web) — the primary product
- **zankurd**: React + Vite prototype for web dashboard (secondary, less active)

Both projects target Kurmanci speakers and include a 3.100+ question bank (offline bank: 3.147 questions across 9 categories, counted 2026-07-19), multiplayer rooms, leaderboard, and coin reward systems.

## Architecture

### Mobile (Flutter) — Primary

The Flutter app follows a **repository pattern** with environment-based switching:

**Data Layer (`lib/src/data/`):**
- `ZanKurdRepository` (abstract) — defines all data operations
- `SupabaseZanKurdRepository` — production implementation using Supabase client; holds a private `MockZanKurdRepository _offline` **by composition** (not inheritance) and falls back to it when the network/schema is unavailable — keep it that way
- `MockZanKurdRepository` — offline/test implementation with hardcoded data
- Selected at startup in `main.dart` based on `AppConfig.hasSupabaseConfig`

**Selection Logic (main.dart:43-52):**
```dart
if (AppConfig.hasSupabaseConfig) {
  repository = SupabaseZanKurdRepository(Supabase.instance.client);
} else {
  repository = MockZanKurdRepository();  // Falls back for testing
}
```

**State Management:**
- Provider 6.1.0 for ChangeNotifier-based providers
- `AuthProvider` — manages auth state (anonymous login, Supabase session)
- `ThemeProvider` — dark/light mode persistence
- `LanguageProvider` — Kurmanci language support
- Local data: per-feature `SharedPreferences` store singletons (aşağıdaki "Local stores" bölümü); coin bakiyesi sunucudan (`coin_transactions` toplamı) okunur

**Environment Configuration (AppConfig):**
```dart
// Read from Dart --define flags or env vars (SUPABASE_URL, SUPABASE_ANON_KEY)
// Fallback support for NEXT_PUBLIC_* prefixed vars
// If empty, defaults to MockZanKurdRepository
```

**Key Models (`lib/src/models/`):**
- `QuizQuestion` — text/image/true-false question with difficulty (1-5) and category
- `GameRoom` — multiplayer room state (online and local)
- `Player` — user profile (name, avatar color, score)
- `LeaderboardEntry` — aggregated stats for ranking
- `WildcardType` / `WildcardState` (`wildcard.dart`) — joker (lifeline) state machine
- `MasteryLevel` (`mastery_level.dart`) — per-category mastery tiers

**Local stores (`lib/src/data/`, all `SharedPreferences`-backed singletons):**
Each follows the same shape: a private constructor, a `static Future<X> load()` that caches `_instance`, and `static void resetInstance()` for test isolation. Mock `SharedPreferences` and call `resetInstance()` in `setUp` (see existing `*_store_test.dart`).
- `AchievementStore` — badge unlocks, cumulative answered count, played categories
- `MasteryStore` — per-category correct-answer count, key `zankurd.mastery.<category>`
- `StreakStore`, `MistakeStore`, `SeenQuestionStore` — daily streak, wrong-answer review pool, seen-question dedupe

### Gameplay Systems (non-obvious cross-cutting features)

**Joker / Wildcard system** (`quiz_screen.dart` + `wildcard.dart`): 4 coin-gated lifelines — 50/50 (20c), Seyirci/audience (30c), Çift Cevap/double-answer (50c), Soru Değiştir/change-question (40c, solo mode only via `widget.room.id == null || widget.botRace`). Coins are deducted **optimistically** in the UI, then `repository.spendCoins(amount, reason)` fires async; a failed backend call is corrected on the next `loadCoinBalance()`. Server-side deduction is the `spend_coins` Postgres RPC (`supabase/spend_coins.sql`, `security definer`, balance guard, negative `coin_transactions` row).

**Mastery system** (`mastery_level.dart` + `mastery_store.dart`): 3 tiers per category by correct answers — Xwendekar (20), Pispor (100), Mamoste (400). `QuizResultScreen` counts correct answers **per `AnswerRecord.category`** (not the room's category, so mixed/daily quizzes attribute correctly) and calls `MasteryStore.addCorrect`, which returns a `MasteryLevel?` (non-null only on a tier-up → promotion banner). Local only, no Supabase sync. Surfaced on category cards (home grid + categories tab) and a profile progress section.

**AppShell tab refresh gotcha** (`app_shell.dart`): the 4 tabs live in an `IndexedStack`, so each tab's `State` is built **once** and kept alive — `initState` does not re-run on tab switch. Screens that snapshot data in `initState` (e.g. `ProfileScreen`'s achievements/stats/mistakes) go stale until app restart. The fix pattern: `AppShell` owns a `ValueNotifier<int>` and bumps it when the tab is selected; the screen takes an optional `refreshSignal` `Listenable` and reloads on change. (Widgets that read a store live in `build()` — like the mastery section — are already current and need no signal.)

### Web (React) — Secondary

Minimal Vite + TypeScript setup in `zankurd/`. Currently just a prototype dashboard. Lower priority for development.

## Linting & Type Checking

**Flutter:**
- `dart analyze` — runs the Dart analyzer (Linting rules in `analysis_options.yaml` use package:flutter_lints). **Use this, not `flutter analyze`.**
- ⚠️ `flutter analyze` **crashes in this environment** with an LSP byte-stream error (`FormatException: Unexpected end of input`). The cause is the Turkish dotted-İ in the home path `C:\Users\AMARGİ\…`: that character is 2 bytes in UTF-8, which desyncs the LSP `Content-Length` header and truncates the analysis-server `initialize` message. `dart analyze` does not use the LSP channel, so it works correctly (reports "No issues found!"). Prefer `dart analyze` everywhere (local + CI) until the path issue is resolved.
- `dart format .` — code formatting
- No dedicated tests runner command; use `flutter test` for unit tests

**React:**
- `npm run lint` in zankurd/ — ESLint (TypeScript + React plugins)
- `npm run build` — TypeScript type checking + Vite build

## Running & Testing

### Flutter (zankurd_mobile)

**Development:**
```bash
cd zankurd_mobile
flutter pub get
flutter run -d <device>        # Run on Android emulator, iOS simulator, or Web
flutter run -d windows         # Run Windows desktop build
flutter run -d chrome          # Run Web build
```

**Testing:**
```bash
flutter test                    # Run all unit tests in test/ directory
flutter test test/question_bank_test.dart    # Run single test file
flutter test --verbose         # More detailed output
```

**Building:**
```bash
flutter build apk              # Android APK (release)
flutter build web              # Web build (release)
flutter build windows          # Windows desktop (release)
```

**Code Quality:**
```bash
dart analyze                   # Static analysis (flutter analyze bu ortamda çöküyor — üstteki nota bak)
dart format lib/ test/         # Auto-format Dart code
```

### React (zankurd)

```bash
cd zankurd
npm install
npm run dev       # Development server on :5173
npm run build     # Production build
npm run lint      # ESLint checks
npm run preview   # Preview production build
```

## Environment Setup & Build Issues

### Windows TMP/TEMP Path Issue

**Critical:** Before running `flutter build` or Gradle commands on Windows, set the TMP/TEMP environment variables:

```powershell
$env:TMP = "C:\src\tmp"
$env:TEMP = "C:\src\tmp"
mkdir C:\src\tmp -Force
flutter build apk  # Now it won't fail with loopback IOException
```

This is a pre-existing issue in the Android Gradle build system. If omitted, Gradle fails with a loopback socket error. Reference: Memory record at [[gradle-loopback-temp-fix]].

### Supabase Configuration

For production builds with Supabase:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-key
```

Or set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` env vars (fallback).

Without these, the app defaults to `MockZanKurdRepository` (offline mode with hardcoded test data).

### Firebase Configuration

Firebase configuration is read from:
- Android: `android/app/google-services.json`
- iOS: Auto-configured via CocoaPods
- Web: Firebase config in code (see `firebase_options.dart`)

Firebase Crashlytics is initialized in `main.dart` (error reporting). It's wrapped in try-catch to allow graceful degradation on platforms without Firebase support.

## Key Development Patterns

### Repository Pattern

Always implement against `ZanKurdRepository` abstract class, never directly against Supabase or Mock. This ensures code works in both online and offline modes:

```dart
// ✅ Correct
final questions = await repository.loadQuestions(categoryId: 'Ziman');

// ❌ Avoid
final response = await supabaseClient.from('questions').select();
```

### Question Validation in Tests

The question bank is validated in `test/question_bank_test.dart`:
- All question IDs must be unique
- Correct answer must exist in the answers list
- Categories must be in the known set: Ziman, Çand, Dîrok, Edebiyat, Cografya, Muzîk, Siyaset, Paradigma, Teknolojî
- Difficulty must be 1-5
- Answer options must be unique per question

If you modify the question bank (in `offline_question_bank.dart`), run tests to validate:
```bash
flutter test test/question_bank_test.dart
```

### State Management Pattern

Use Provider's `ChangeNotifier` for simple state:
```dart
class MyProvider extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  
  void increment() {
    _count++;
    notifyListeners();
  }
}

// In widget tree, wrap with MultiProvider in main.dart
// Use Consumer<MyProvider> to rebuild on changes
```

### Local Data Persistence

Local data (streak, achievements, mastery, seen questions, missions, XP) is stored in `SharedPreferences` via the per-feature singleton stores (`AchievementStore`, `MasteryStore`, `MistakeStore`, `XPStore`, etc. — see "Local stores" above). **Coins are server-authoritative:** balance is the sum of `coin_transactions`; all writes go through security-definer RPCs (`spend_coins`, `claim_quiz_reward`, `claim_daily_spin`, `claim_extra_spin`, `claim_mission_reward`, `claim_tournament_reward`). There is no client-side "add arbitrary coins" path — do not reintroduce one.

## Release State & Important Notes

**Current Version:** 1.9.1+13 (pubspec.yaml, tek doğru sürüm kaynağı — bkz. kök `CURRENT_STATUS.md`) — last tagged release v1.9.0-internal.1 (2026-07-18)

AnalyticsService artık STUB değildir: Firebase Analytics'e bağlı gerçek implementasyondur (init başarısızsa graceful degrade; cihazda olay doğrulaması henüz yapılmadı). NotificationService de MOCK/Timer simülasyonu değildir: `flutter_local_notifications` ile gerçek yerel günlük hatırlatıcılar zamanlanır. Online 1v1 (Supabase realtime) gerçektir ancak iki gerçek cihazla uçtan uca test edilmemiştir.
- `supabase/2026-07-03_reward_hardening.sql` canlıya uygulandı (2026-07-03): claim_* ödül RPC'leri, profiles.xp, questions.explanation_ku/tr, skor/XP guard trigger'ları canlıda aktif
- `supabase/2026-07-03_matchmaking_fix.sql` canlıya uygulandı (2026-07-03): join_matchmaking + matchmaking_queue (realtime yayınında) canlıda aktif; online 1v1 eşleşmede sorular room_questions'tan okunur
- `supabase/2026-07-13_curated_question_wave_1.sql` canlıya uygulandı (2026-07-15, Management API ile, `category`→`category_id` ve NULL option düzeltmesiyle): `curated_movement_wave_1` kaynaklı 8 soru (Siyaset/Paradigma/Çand) canlıda onaylı

**Known Issues:**
- Windows Profile-tab navigation can hang on some debug builds (pre-existing, not related to fonts or recent changes — don't investigate without explicit request)

**Testing Before Release:**
- Run `dart analyze` to catch linting issues
- Run `flutter test` to validate question bank and data structures
- Test on both Android emulator and real device before building APK

## Design Spec Discipline

Aynı anda yalnızca **bir** aktif "tam uygulama yeniden tasarımı" (full
app/visual redesign) spec'i olabilir `zankurd_mobile/docs/superpowers/specs/`
altında. Yeni bir tam-uygulama redesign spec'i yazmadan önce:
1. Var olan aktif redesign spec'ini (varsa) süpersede edildiğini belirten
   bir not ekleyerek kapat.
2. Kapatılan spec'i `zankurd_mobile/docs/superpowers/specs/_archive/`
   altına taşı.

Bu kural yalnızca **tüm uygulamayı** kapsayan redesign spec'lerine
uygulanır (ör. "Bubblegum Arcade"); tek bir ekran/paket için yazılan
odaklı spec'ler (ör. "Faz D — Öğrenme Bölgesi") bu kısıtlamaya tabi
değildir. Amaç: 2026-07-10/12 döneminde 48 saat içinde 5 çakışan
tam-uygulama redesign spec'inin yazılmasına yol açan döngüyü önlemek
(bkz. `zankurd_mobile/docs/superpowers/specs/2026-07-15-karmasiklik-giderme-design.md`).

## Dart/Flutter Conventions in This Project

- **Imports:** Use relative imports for local files, absolute for packages (`package:zankurd_mobile/...`)
- **Naming:** Private fields with `_` prefix, PascalCase for classes, camelCase for methods/fields
- **Comments:** Minimal; only explain WHY, not WHAT. Exception: Turkish comments are acceptable (e.g., `// Profil satırı yoksa oluşturur`)
- **Error Handling:** Use try-catch at data layer (repository); surface meaningful errors to UI via providers
- **Null Safety:** Strict null safety enabled; use `?` and `!` intentionally

## File Organization

```
zankurd_mobile/lib/src/
├── config/          # App configuration (Supabase URL, etc.)
├── data/            # Repository implementations, local storage services
├── models/          # Data classes (QuizQuestion, Player, etc.)
├── providers/       # Provider-based state management (Auth, Theme, Language)
├── screens/         # Full screens (home, quiz, leaderboard, etc.)
├── theme/           # Material theme configuration
├── widgets/         # Reusable components (buttons, dialogs, loaders)
├── utils/           # Utilities (error reporting, etc.)
├── l10n/            # Localization (Kurmanci language strings)
├── game/            # Game logic (bot opponent, etc.)
└── animations/      # Animation utilities

test/               # Unit and widget tests
```

## Quick Reference: Common Tasks

| Task | Command |
|------|---------|
| Run app (Android) | `flutter run -d emulator-5554` |
| Run app (Web) | `flutter run -d chrome` |
| Run app (Windows) | `flutter run -d windows` |
| Build APK | `flutter build apk` (after setting TMP/TEMP) |
| Run all tests | `flutter test` |
| Run one test file | `flutter test test/streak_store_test.dart` |
| Lint Dart | `dart analyze` |
| Format Dart | `dart format lib/ test/` |
| Check pub dependencies | `flutter pub outdated` |
| Upgrade dependencies | `flutter pub upgrade` |
| Clean build artifacts | `flutter clean` |

## Supabase Schema Notes

The Supabase backend has tables for questions, profiles, rooms, and coin transactions. See `docs/supabase_schema.sql` (or ask Supabase directly) for the full schema. Key tables:
- `questions` — question bank (id, category, difficulty, answers, correct_answer)
- `profiles` — user profiles (id, display_name, avatar_color)
- `rooms` — multiplayer rooms (code, category, status)
- `coin_transactions` — audit trail of coin changes

The app interacts via the repository abstraction; direct SQL is not written in the app code.

## React/Web Project (Lower Priority)

The `zankurd/` folder contains an MVP dashboard prototype. It's less actively developed than the mobile app. Commands are standard:

```bash
cd zankurd
npm run dev       # Dev server
npm run build     # Type-check and build
npm run lint      # Check code style
```

No special setup or patterns beyond standard React + TypeScript conventions.
