# ZanKurd Mimari Belgeleri

## Genel Bakış

ZanKurd, Kurmancî (Kürtçe) bilgi yarışması uygulamasıdır. Flutter ile geliştirilmiş olup,
Supabase backend ve Firebase entegrasyonu ile çalışır.

## Mimari Diyagram

```mermaid
graph TB
    subgraph UI["Kullanıcı Arayüzü (Screens)"]
        HS[HomeScreen]
        QS[QuizScreen]
        PS[ProfileScreen]
        LS[LeaderboardScreen]
        SS[SettingsScreen]
    end

    subgraph Providers["State Management (Provider)"]
        AP[AuthProvider]
        TP[ThemeProvider]
        LP[LanguageProvider]
        SP[SoundProvider]
    end

    subgraph Services["Servisler"]
        ANS[AnalyticsService]
        NS[NotificationService]
        BS[BadgeService]
    end

    subgraph Data["Veri Katmanı"]
        REPO[ZanKurdRepository]
        SUPA[SupabaseZanKurdRepository]
        MOCK[MockZanKurdRepository]
        SM[SyncManager]
    end

    subgraph Stores["Yerel Depolar (SharedPreferences)"]
        AS[AchievementStore]
        MS[MistakeStore]
        SS2[StreakStore]
        XS[XpStore]
        MAS[MasteryStore]
        DMS[DailyMissionStore]
    end

    subgraph Backend["Backend"]
        SB[(Supabase)]
        FB[(Firebase)]
    end

    UI --> Providers
    UI --> Data
    UI --> Services
    Providers --> Data

    REPO --> SUPA
    REPO --> MOCK
    SUPA --> SB
    SM --> SUPA

    ANS --> FB
    BS --> Stores
    NS --> FB

    Data --> Stores
```

## Katmanlar

### 1. UI Katmanı (`lib/src/screens/`)
- **HomeScreen** — Ana sayfa, kategori seçimi, hızlı yarış
- **QuizScreen** — Soru-cevap ekranı, zamanlayıcı, joker
- **ProfileScreen** — Kullanıcı profili, istatistikler, rozetler, XP
- **LeaderboardScreen** — Anonim lider tablosu
- **SettingsScreen** — Dil seçimi (KU/TR), tema geçişi, ses, oyuncu adı

### 2. State Management (`lib/src/providers/`)
- **AuthProvider** — Supabase kimlik doğrulama
- **ThemeProvider** — Aydınlık/Karanlık tema yönetimi
- **LanguageProvider** — Kurmancî/Türkçe dil yönetimi
- **SoundProvider** — Ses efektleri açma/kapama (web'de sessizdir)
- **ReducedMotionProvider** — Hareketi azalt (kullanıcı + sistem tercihi)
- **PremiumService** — RevenueCat aboneliği (`ChangeNotifier`)

### 3. Servisler (`lib/src/services/`)
- **AnalyticsService** — Anonim kullanım istatistikleri (Firebase Analytics)
- **NotificationService** — Günlük hatırlatıcı bildirimleri
- **BadgeService** — Genişletilmiş rozet/streak değerlendirmesi

### 4. Veri Katmanı (`lib/src/data/`)
- **ZanKurdRepository** — Soyut repository arayüzü
- **SupabaseZanKurdRepository** — Supabase bağlantılı gerçek uygulama
- **MockZanKurdRepository** — Test ve offline ortam için mock
- **SyncManager** — Offline XP senkronizasyonu

### 5. Yerel Depolar (`lib/src/data/`)
- **AchievementStore** — Rozet ilerlemesi ve kilit açma durumu
- **MistakeStore** — SM-2 algoritması ile yanlış soru takibi
- **StreakStore** — Günlük oyun serisi
- **XpStore** — Deneyim puanı ve seviye hesaplama
- **MasteryStore** — Kategori bazlı ustalık seviyeleri
- **DailyMissionStore** — Günlük görev ilerlemesi

## Teknoloji Yığını

| Katman | Teknoloji |
|--------|-----------|
| **Framework** | Flutter 3.44+ |
| **Dil** | Dart 3.12+ |
| **State** | Provider (ChangeNotifier) |
| **Backend** | Supabase (Auth, Database, Realtime) |
| **Crash Reporting** | Firebase Crashlytics |
| **Analitik** | Firebase Analytics |
| **Yerel Depo** | SharedPreferences |
| **Ses** | audioplayers |
| **Animasyonlar** | Flutter yerleşik (`AnimationController`, `CustomPainter`) |
| **CI/CD** | GitHub Actions |

## Çift Dilli Destek

Uygulama Kurmancî (KU) ve Türkçe (TR) dillerini destekler:
- `lib/src/l10n/lang.dart` — `LanguageProvider` ve `LangContext` extension
- `lib/src/l10n/strings.dart` — **anahtar tabanlı kayıt defteri**; metinlerin
  tek kaynağı burasıdır (`K.anahtar` → `{ku, tr}`)
- Ekranlarda `context.t(K.anahtar)` kullanılır. `context.s(ku, tr)` yalnız
  geriye dönük uyumluluk için duruyor ve yeni kullanımı bekçi testini kırar
  (`test/l10n_migration_guard_test.dart`).

> `intl_tr.arb` / `intl_ku.arb` dosyaları YOKTUR; bu belge 2026-07-31'e
> kadar onları kaynak gibi gösteriyor ve yeni geliştiriciyi var olmayan
> bir API'ye yönlendiriyordu.

## Tema Sistemi

- `lib/src/theme/app_theme.dart` — Light ve Dark tema tanımları
- `lib/src/providers/theme_provider.dart` — Tema durumunu yönetir
- Glassmorphism: `lib/src/widgets/glass_panel.dart`
- Renkler: Coral/Orange gradient, Indigo secondary, Gold accent
