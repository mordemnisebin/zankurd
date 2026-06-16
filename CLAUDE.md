# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🇹🇷 Dil Ayarı

**Claude, bu proje hakkında HER ZAMAN Türkçe konuş. İngilizce kullanma.**

Kod yorum ve string'ler için: Kodda Türkçe/Kürtçe yorum varsa koru, ama yeni kod yazarken proje standardını takip et. Proje iletişimi tamamen Türkçedir.

---

## Project Overview

**Zankurd** is a Kurmanci-language live quiz application with two main components:
- **zankurd_mobile**: Flutter mobile app (Android/iOS/Web) — the primary product
- **zankurd**: React + Vite prototype for web dashboard (secondary, less active)

Both projects target Kurmanci speakers and include a 2250+ question bank, multiplayer rooms, leaderboard, and coin reward systems.

## Architecture

### Mobile (Flutter) — Primary

The Flutter app follows a **repository pattern** with environment-based switching:

**Data Layer (`lib/src/data/`):**
- `ZanKurdRepository` (abstract) — defines all data operations
- `SupabaseZanKurdRepository` — production implementation using Supabase client
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
- Local data: `LocalDataService` (coin balance, achievements, seen questions, streaks)

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
flutter analyze                # Static analysis
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
- Categories must be in the known set: Ziman, Çand, Dîrok, Edebiyat, Cografya, Muzîk
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

Local data (coins, streak, achievements, seen questions) is stored in `SharedPreferences`. Services in `lib/src/data/` handle persistence:

```dart
LocalDataService.addCoins(amount)          // Update balance
LocalDataService.coins                     // Read balance
LocalDataService.applyQuizResult(...)      // Update on quiz completion
```

## Release State & Important Notes

**Current Release:** v1.3.0+4 (tagged v1.3.0-internal.1 on 2026-06-12)
- The build is validated and ready for Play Console submission
- Only user-facing Play Console configuration steps remain

**Known Issues:**
- Windows Profile-tab navigation can hang on some debug builds (pre-existing, not related to fonts or recent changes — don't investigate without explicit request)

**Testing Before Release:**
- Run `flutter analyze` to catch linting issues
- Run `flutter test` to validate question bank and data structures
- Test on both Android emulator and real device before building APK

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
| Lint Dart | `flutter analyze` |
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
