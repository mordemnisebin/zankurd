# ZanKurd — Güncel Durum (CURRENT_STATUS)

> ⚠️ **TEK GÜNCEL DURUM KAYNAĞI BU DOSYADIR.** Kökteki diğer tüm durum/rapor
> dokümanları tarihseldir; eski oturum raporları `arsiv/` klasörüne taşınmıştır.
> Bu dosya ile başka bir doküman çelişirse bu dosya geçerlidir.
>
> Son güncelleme: 2026-07-20
> Bu belge, projenin gerçek durumunu özetler. Pazarlama dili değil, mühendislik gerçeği içerir.

---

## 0. TASARIM YÖNÜ — PIVOT (2026-07-20, kullanıcı kararı)

**ZanKurd artık Pirs (Pêşbirka Kurdî) formatına hizalanır.** Önceki
"koyu-öncelikli + kültürel-derinlik" yönü BIRAKILDI. Uygulanan (commit'li,
push'lı, canlıda):

- **Açık tema varsayılan** + **turuncu marka** (`AppTheme.brandGreen`=`0xFFF5931E`)
- **Parlak Pirs accent + kategori renkleri**; **kilim motifi kaldırıldı**
  (`KilimPatternPainter` no-op); **kategori kartları kompakt**; Yarış hub 3 mod
- **KORUNAN** (kullanıcı kararı): Kurmancî unvanlar (Xwendekar/Pispor/Mamoste)
  ve Zana maskotu + günün sözü
- Eski koyu/kültürel mockup ve redesign spec'leri (ÖRNEK TASARIM, bubblegum,
  visual-redesign vb.) SİLİNDİ — çelişki yaratmasınlar diye.

Kalan: kilim ölü-kod temizliği, mağaza earn-coin-cta overflow (390x844).
Detay: memory `[[design-direction-2026-07]]` ve CLAUDE.md kimlik bölümü.

---

## 1. Projenin Aktif Ürünü

- **Aktif ürün:** `zankurd_mobile` — Flutter ile yazılmış Kurmancî quiz/yarışma uygulaması (Android öncelikli; Web/Windows/iOS hedefleri mevcut).
- **İkincil/Prototip:** `zankurd/` — React + Vite web dashboard prototipi; aktif geliştirilmiyor.
- Kök dizindeki `görseller/`, `output/`, `Pirs_apk_extracted/` vb. klasörler çıktı/medya klasörüdür, ürün kodu değildir.

## 2. Mevcut Sürüm

- **Aktif sürüm (tek doğru kaynak):** `1.9.1+13` — `zankurd_mobile/pubspec.yaml`
- **Tarihsel referanslar (dokümanlarda "geçmiş" olarak kalmalı):** `1.3.0+4` (Play doğrulanmış build, 2026-06-15), `1.5.0+6`, `1.9.0+12` (son etiketli release v1.9.0-internal.1, 2026-07-18).

## 3. Ana Teknoloji

- **Flutter** / **Dart** (`C:\src\flutter` altında kurulu)
- **Durum yönetimi:** Provider 6.1 (ChangeNotifier)
- **Backend:** Supabase (`supabase_flutter`) — yapılandırma yoksa otomatik `MockZanKurdRepository`'ye düşer
- **Kalıcı yerel veri:** `shared_preferences` (streak, mastery, rozet, görülen sorular, XP)
- **Coin bakiyesi sunucu-otoriterdir:** `coin_transactions` toplamı; tüm yazmalar security-definer RPC'ler üzerinden
- **Crash reporting + Analytics:** Firebase Crashlytics + Firebase Analytics (try-catch korumalı)
- **Ek paketler:** audioplayers, shimmer, lottie, share_plus, in_app_review, connectivity_plus, flutter_local_notifications

## 4. Servislerin Gerçek Durumu

| Servis / Özellik | Durum | Açıklama |
|---|---|---|
| **AnalyticsService** | **GERÇEK (Firebase'e bağlı)** | Firebase Analytics entegre; init başarısız olursa graceful degrade (yalnız debugPrint). ⚠️ Olayların gerçek cihazda Firebase Console'a ulaştığı **henüz doğrulanmadı**. |
| **NotificationService** | **GERÇEK** | `flutter_local_notifications` ile gerçek yerel günlük hatırlatıcılar zamanlanıyor (eski Timer simülasyonu değil). |
| **Turnuva** | **GERÇEK ama bot tabanlı** | Çevrimiçi insan turnuvası değil; bot rakiplere karşı yerel akış (çeyrek/yarı/final). |
| **1v1 (online matchmaking)** | **GERÇEK (Supabase realtime)** | `join_matchmaking` RPC + `matchmaking_queue` realtime yayını canlıda aktif; sorular `room_questions`'tan okunur. ⚠️ **İki gerçek cihazla uçtan uca hiç test edilmedi.** |
| **MockZanKurdRepository** | **MOCK (bilinçli)** | Supabase yapılandırması yokken offline test verisi. Tasarım gereği. |
| **Crashlytics** | **GERÇEK ama koşullu** | try-catch ile sarılı; Firebase desteklemeyen platformlarda sessizce devre dışı. |

## 5. Soru Bankası Durumu

- **Aktif veri kaynağı:** Üretimde Supabase `questions` tablosu; fallback olarak kod içi `offline_question_bank.dart`.
- **Offline kod bankası:** **3.147 soru** (dosyadan sayıldı, 2026-07-19), **9 kategori**:
  - Ziman — 433
  - Dîrok — 395
  - Cografya — 392
  - Siyaset — 386
  - Muzîk — 386
  - Çand — 383
  - Edebiyat — 382
  - Paradigma — 378
  - Teknolojî — 12
- Kategori kümesi `test/question_bank_test.dart` tarafından doğrulanıyor (Siyaset, Paradigma, Teknolojî dahil).
- **Kök CSV'ler:** `zankurd_soru_bankasi_cevapli.csv` (ham kaynak) ve `zankurd_soru_bankasi_cevapli_DUZELTILMIS.csv` (düzeltilmiş sürüm, kökte mevcut — doğrulandı). Bunlar içe aktarma kaynaklarıdır, canlı veri kaynağı değildir.

## 6. Çalışan Özellikler (Özet)

Quiz akışı (kategori/günlük/seviye/oda), coin + joker sistemi (50/50, Seyirci, Çift Cevap, Soru Değiştir), Mastery (Xwendekar/Pispor/Mamoste), rozet/streak/hata havuzu, XP/seviye, liderlik tablosu (Supabase view + Mock fallback), çevrimiçi odalar (Supabase RPC + realtime), çark (spin wheel), günlük görevler, ses sistemi, auth (anonim + Supabase + Google OAuth), koyu/açık tema, Kurmancî dil desteği, Zana günlük kartı.

## 7. Bilinen Kalan Borçlar

1. **God-file'lar:** Bazı ekran/servis dosyaları (ör. `quiz_screen.dart`, `offline_question_bank.dart`) çok büyük; refactor planlı ama yapılmadı.
2. **Hardcoded Supabase key:** `lib/src/config/app_config.dart` içinde varsayılan Supabase URL + publishable key koda gömülü. Publishable (anon) key olduğundan kritik sızıntı değil, ama temizlenmesi/`--dart-define`'a taşınması önerilir.
3. **Analytics cihazda doğrulanmadı:** Firebase Analytics kodu gerçek ama olay akışı canlı cihazda gözlemlenmedi.
4. **1v1 iki gerçek cihazla test edilmedi** (bkz. §4).
5. **ZK CSV düzeltmesi tamamlandı:** `zankurd_soru_bankasi_cevapli_DUZELTILMIS.csv` kökte mevcut; sorunlu ZK kayıtları düzeltilmiş durumda.

## 8. Güvenlik Notları

- **İmzalama dosyaları:** `android/key.properties` ve `android/upload-keystore.jks` git takibinde değil; gizli materyaldir — paylaşılmamalı, loglanmamalı.
- **Takip edilen yapılandırma:** `android/app/google-services.json` git'te mevcut (Firebase istemci yapılandırması, sunucu sırrı değil).
- Supabase publishable key kodda gömülü (bkz. §7-2).

## 9. Release Öncesi Yapılacaklar

1. `dart analyze` temiz + `flutter test` tüm testler geçmeli (son kontrol 2026-07-19: analyze temiz, **637 test geçti, 2 atlandı, 0 hata**).
2. Final AAB üretimi (ASCII build yolundan, TMP/TEMP ayarlı).
3. Üretilen AAB için `jarsigner -verify` ile imza doğrulaması.
4. Supabase SQL dosyalarının canlı projeye uygulandığının teyidi.
5. 1v1'in iki gerçek cihazla uçtan uca testi.
6. Firebase Analytics olaylarının gerçek cihazda doğrulanması.
7. Play Console manuel adımları (Data Safety, derecelendirme, gizlilik politikası, ekran görüntüleri, sürüm notları).

## 10. Codex/Claude İçin Güvenli Çalışma Kuralları

- **Yeni özellik ekleme; UI tasarımını yeniden yazma; iş mantığını bozma; büyük refactor yapma.**
- Mevcut ekranları, quiz/auth akışını, Supabase entegrasyonunu **değiştirme**.
- **İmzalama dosyalarına dokunma:** `key.properties`, `*.jks`, `*.keystore`, `*.p12`, `*.pem`, `.env`.
- Soru bankasını **toplu dönüştürme**; içerik değişikliği gerekiyorsa önce rapor yaz.
- Veriye repository soyutlaması üzerinden eriş (`ZanKurdRepository`).
- Lint için **`dart analyze`** kullan (`flutter analyze` bu ortamda Türkçe-İ yol hatası nedeniyle çöker).
- Build öncesi **TMP/TEMP** ayarla ve mümkünse **ASCII build yolu** kullan.
- Proje iletişimi ve dokümanlar **Türkçe**.
