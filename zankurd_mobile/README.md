# ZanKurd Mobile

ZanKurd, Kurmanci odaklı bir bilgi yarışması uygulamasıdır. Bu klasör Play Store'a gönderilecek ana Flutter uygulamasıdır.

Web prototipi `../zankurd` altında durur; Play Console'a yüklenecek paket bu projeden üretilir.

## Ürün Kapsamı

- Misafir/anonim giriş ve profil adı akışı
- Kurmanci/Türkçe arayüz geçişi (çift dilli ARB dosyaları)
- Aydınlık/Karanlık tema geçişi
- Kategori ve seviye bazlı quiz
- Günlük yarışma
- Günlük çark ve coin ödülleri
- Favori sorular, yanlışlardan tekrar ve soru bildirme
- Online oda, canlı oyuncu listesi ve liderlik tablosu
- Rozet & Streak sistemi (30 gün, 500/1000 soru, mükemmel oyun, hız)
- SM-2 aralıklı tekrar algoritması ile yanlış soru takibi
- Günlük push hatırlatıcı bildirimleri (saat seçimi ile)
- Anonim kullanım analitikleri (Firebase Analytics)
- Glassmorphism efektli modern UI bileşenleri
- Uygulama içinden hesap silme isteği
- Firebase Crashlytics ile çökme raporlama
- Offline XP senkronizasyonu

## Mimari

Detaylı mimari belgeler için [ARCHITECTURE.md](ARCHITECTURE.md) dosyasına bakınız.

- `lib/main.dart`: Firebase/Crashlytics, Analytics ve Supabase başlangıcı
- `lib/src/data/`: Repository, SM-2, Streak, Badge, XP ve Sync veri katmanı
- `lib/src/screens/`: Ana ekran, quiz, liderlik, profil, ayarlar ve oda akışları
- `lib/src/widgets/`: Ortak panel, badge widget, glass panel, chart bileşenleri
- `lib/src/theme/`: Material 3 tema, glassmorphism ve renk sistemi
- `lib/src/l10n/`: Kurmanci/Türkçe çeviri dosyaları (ARB) ve dil yardımcıları
- `lib/src/services/`: Analitik, bildirim ve rozet servisleri
- `lib/src/providers/`: Auth, Theme, Language ve Sound state management
- `supabase/`: Play sürümü için gereken SQL/RPC/policy dosyaları

## Geliştirme

```powershell
flutter pub get
flutter run -d chrome
flutter run -d windows
flutter run -d emulator-5554
```

Varsayılan build ZanKurd production Supabase projesine bağlanır; ekstra parametre gerekmez:

```powershell
flutter run
flutter build appbundle --release
```

Farklı bir Supabase projesiyle çalıştırmak için build-time override verilebilir:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-publishable-or-anon-key
```

## Doğrulama

```powershell
dart analyze
flutter test --exclude-tags preview

Pushd widgetbook
flutter pub get
dart analyze
Pop-Location
```

Kök analiz yalnız ZanKurd uygulama paketini doğrular. Bağımsız Widgetbook
paketi kendi bağımlılıkları ve analyzer ayarlarıyla ayrıca doğrulanmalıdır.

### Soru kalitesi denetimi

Soru kaynaklarının rolleri `tool/question_quality/source_manifest.json`
dosyasında açıkça tanımlanır. Bütün sınıflandırılmış kaynakların raporunu üretmek
için:

```powershell
dart run tool/question_quality/question_quality_audit.dart report
```

Commitlenmiş baseline'a göre yalnız yeni veya artan kalite borcunu denetlemek
için:

```powershell
dart run tool/question_quality/question_quality_audit.dart gate
```

Baseline otomatik yenilenmez. Mevcut rapor ve değişiklik özeti incelendikten
sonra borç bilinçli olarak kabul edilecekse açık bayrak gerekir:

```powershell
dart run tool/question_quality/question_quality_audit.dart baseline --accept-current-debt
```

`Unclassified question source detected.` hatası yeni kaynağın sessizce runtime
veya publish toplamına alınmadığını gösterir. Yeni soru kaynağı ekleme sırası:

1. Dosyayı oluşturun.
2. Manifestte açık bir rol, parser ve `canonicalGroup` tanımlayın.
3. `report` modunu çalıştırıp physical/canonical ve cross-source etkisini inceleyin.
4. `gate` etkisini doğrulayın.
5. Yalnız bilinçli inceleme sonrasında baseline'ı açık kabul bayrağıyla yenileyin.
6. CI sonucunu doğrulayın.

`canonicalGroup`, aynı mantıksal bankanın farklı runtime/import/publish
kopyalarını global kanonik sayımda uzlaştırırken ilgisiz havuzların yanlışlıkla
birleştirilmesini engeller.

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
