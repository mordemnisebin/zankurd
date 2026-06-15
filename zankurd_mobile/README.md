# ZanKurd Mobile

ZanKurd, Kurmanci odaklı bir bilgi yarışması uygulamasıdır. Bu klasör Play Store'a gönderilecek ana Flutter uygulamasıdır.

Web prototipi `../zankurd` altında durur; Play Console'a yüklenecek paket bu projeden üretilir.

## Ürün Kapsamı

- Misafir/anonim giriş ve profil adı akışı
- Kurmanci/Türkçe arayüz geçişi
- Kategori ve seviye bazlı quiz
- Günlük yarışma
- Günlük çark ve coin ödülleri
- Favori sorular, yanlışlardan tekrar ve soru bildirme
- Online oda, canlı oyuncu listesi ve liderlik tablosu
- Uygulama içinden hesap silme isteği
- Firebase Crashlytics ile çökme raporlama

## Mimari

- `lib/main.dart`: Firebase/Crashlytics ve Supabase başlangıcı, repository seçimi
- `lib/src/data/`: `ZanKurdRepository` soyutlaması, Supabase ve mock uygulamaları
- `lib/src/screens/`: Ana ekran, quiz, liderlik, profil, ayarlar ve oda akışları
- `lib/src/widgets/`: Ortak panel, buton, giriş, hata ve yükleme bileşenleri
- `lib/src/theme/`: Material 3 tema ve renk sistemi
- `lib/src/l10n/`: Kurmanci/Türkçe dil yardımcıları
- `supabase/`: Play sürümü için gereken SQL/RPC/policy dosyaları

Supabase canlı backend için kullanılır. Supabase yapılandırması yoksa uygulama mock/offline repository ile açılır. Firebase bu sürümde Crashlytics ve platform başlangıcı için kullanılır.

## Geliştirme

```powershell
flutter pub get
flutter run -d chrome
flutter run -d windows
flutter run -d emulator-5554
```

Supabase ile çalıştırmak için:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-publishable-or-anon-key
```

## Doğrulama

```powershell
flutter analyze
flutter test
```

Windows'ta Android/Gradle build öncesi geçici dizini ASCII bir yola alın:

```powershell
New-Item -ItemType Directory -Force -Path 'C:\src\tmp'
$env:TMP='C:\src\tmp'
$env:TEMP='C:\src\tmp'
```

## Play Store Build

```powershell
flutter build appbundle --release
```

Play Console'a yüklenecek dosya:

```text
build/app/outputs/bundle/release/app-release.aab
```

İmza doğrulama:

```powershell
jarsigner -verify -verbose -certs 'build/app/outputs/bundle/release/app-release.aab'
```

## Play Console Hazırlığı

Play Console'a yüklemeden önce şu dosyaları kontrol edin:

- `docs/release_readiness.md`
- `docs/play_console_submission_checklist.md`
- `docs/play_store_internal_test.md`
- `docs/privacy_policy.html`
- `docs/release_notes_internal.md`

Google Play'de gizlilik politikası için `docs/privacy_policy.html` dosyası herkese açık bir HTTPS URL'de yayınlanmalı ve aynı URL Play Console'daki Privacy Policy alanına girilmelidir.

## Canlı Backend SQL Sırası

Supabase SQL Editor'de en az şu dosyalar uygulanmış olmalıdır:

1. `supabase/public_read_policies.sql`
2. `supabase/online_room_policies.sql`
3. `supabase/online_game_sync.sql`
4. `supabase/leaderboard_view.sql`
5. `supabase/submit_answer_function.sql`
6. `supabase/daily_spin_rpc.sql`
7. `supabase/quiz_reward_rpc.sql`
8. `supabase/coin_policies.sql`
9. `supabase/delete_my_account_rpc.sql`

Soru bankası temizliği için `supabase/dedupe_and_fix_questions.sql` ayrıca çalıştırılabilir.
