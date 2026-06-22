# ZanKurd — Güncel Durum (CURRENT_STATUS)

> Son güncelleme: 2026-06-22
> Bu belge, release öncesi projenin gerçek durumunu özetler. Pazarlama dili değil, mühendislik gerçeği içerir.

---

## 1. Projenin Aktif Ürünü

- **Aktif ürün:** `zankurd_mobile` — Flutter ile yazılmış Kurmancî dilinde quiz/yarışma uygulaması (Android öncelikli, ayrıca Web/Windows/iOS hedefleri mevcut).
- **İkincil/Prototip:** `zankurd/` — React + Vite tabanlı web dashboard prototipi. Düşük öncelikli, aktif geliştirilmiyor.
- Kök dizindeki diğer klasörler (`görseller/`, `output/`, `Pirs_apk_extracted/`, `.agents/`, `.playwright-mcp/`) çıktı/medya/araç klasörüdür ve kök `.gitignore` ile dışlanmıştır.

## 2. Mevcut Sürüm

- **Aktif sürüm (tek doğru kaynak):** `1.5.0+6` — `zankurd_mobile/pubspec.yaml`
- Uygulama içi gösterilen sürüm (`SettingsScreen.appVersion`) bu çalışmada `1.3.0+4` → **`1.5.0+6`** olarak düzeltildi.
- `docs/release_readiness.md` zaten `1.5.0+6` gösteriyor (güncel).
- **Önceki sürümler (tarihçe, dokunulmadı):** `1.3.0+4` (Play doğrulanmış build, 2026-06-15), yol planında `1.4.0+5`. Bu referanslar dokümanlarda "geçmiş" olarak kalmalıdır.

## 3. Ana Teknoloji

- **Flutter** 3.44.1 / **Dart** 3.12.1
- **Durum yönetimi:** Provider 6.1 (ChangeNotifier)
- **Backend:** Supabase (`supabase_flutter`) — yapılandırma yoksa otomatik `MockZanKurdRepository`'ye düşer
- **Kalıcı yerel veri:** `shared_preferences` (coin, streak, mastery, rozet, görülen sorular)
- **Çökme raporu:** Firebase Crashlytics (try-catch ile korumalı)
- **Ek paketler:** audioplayers (ses), shimmer (iskelet yükleme), lottie, share_plus, in_app_review, connectivity_plus

## 4. Ana Klasörler

```
pirs kurmanci/
├── zankurd_mobile/        # ANA ÜRÜN (Flutter)
│   ├── lib/src/
│   │   ├── config/        # AppConfig (Supabase URL/anahtar)
│   │   ├── data/          # Repository + yerel store'lar
│   │   ├── models/        # Veri sınıfları
│   │   ├── providers/     # Auth / Theme / Sound
│   │   ├── services/      # Analytics / Notification
│   │   ├── screens/       # Ekranlar
│   │   ├── widgets/       # Yeniden kullanılabilir bileşenler
│   │   ├── theme/ l10n/ game/ animations/ utils/
│   ├── test/              # Birim/widget testleri
│   ├── supabase/          # SQL şema & RPC dosyaları
│   ├── docs/              # Release/teknik dokümanlar
│   └── android/ ios/ web/ windows/ linux/ macos/
├── zankurd/               # React web prototipi (ikincil)
├── docs/                  # Kök seviyesi dokümanlar
├── zankurd_soru_bankasi_cevapli.csv   # Harici soru CSV'si (120 soru)
└── (görseller/, output/, Pirs_apk_extracted/ → gitignore)
```

## 5. Çalışan Özellikler (Gerçek)

- **Quiz akışı:** kategori/günlük/seviye/oda soruları, A/B/C/D çok-renkli şıklar — çalışıyor.
- **Coin sistemi:** kazanma/harcama, Supabase `spend_coins` / ödül RPC'leri + Mock; iyimser UI düşümü.
- **Joker (Wildcard) sistemi:** 50/50 (20c), Seyirci (30c), Çift Cevap (50c), Soru Değiştir (40c, yalnız solo) — çalışıyor.
- **Mastery sistemi:** kategori başına 3 kademe (Xwendekar/20, Pispor/100, Mamoste/400), yerel — çalışıyor.
- **Rozet / Streak / Hata havuzu (Mistake):** `AchievementStore`, `StreakStore`, `MistakeStore` — yerel, çalışıyor.
- **XP / Seviye:** `XpStore` + level ekranı — çalışıyor.
- **Liderlik tablosu:** Supabase view (`leaderboard_view.sql`) tabanlı, Mock fallback'li — çalışıyor.
- **Çevrimiçi çok oyunculu odalar:** Supabase RPC'leri (`join_room_by_code`, `start_room_game`, `submit_answer` vb.), gerçek zamanlı abonelik — çalışıyor (Supabase yapılandırması gerekir).
- **Çark (Spin Wheel):** günlük coin ödülü, cooldown — çalışıyor.
- **Turnuva:** bot rakiplere karşı yerel turnuva (çeyrek/yarı/final), SharedPreferences ile kalıcı — çalışıyor (gerçek çevrimiçi turnuva değil, bot tabanlı).
- **Günlük görevler:** `DailyMissionStore` — çalışıyor (yerel).
- **Ses sistemi:** `SoundProvider` + audioplayers, 5 ses dosyası mevcut (correct/wrong/win/coin/wildcard) — çalışıyor (Web'de devre dışı).
- **Auth:** anonim + Supabase oturum, Google OAuth deep-link — çalışıyor (Supabase yapılandırması gerekir).
- **Tema/Dil:** koyu/açık tema + Kurmancî dil desteği — çalışıyor.

## 6. Yarım / Mock / Stub Özellikler

| Özellik | Durum | Açıklama |
|---|---|---|
| **AnalyticsService** | **STUB** | Yalnız `debugPrint` üretir. Firebase Analytics entegrasyonu TODO. Olay API'leri hazır ama gerçek kayıt yok. |
| **NotificationService** | **MOCK/SİMÜLASYON** | `Timer` ile her 10 sn kontrol eden, gerçek push olmayan simülasyon. Native katman (`flutter_local_notifications`) eklenmemiş. Ayar/saat kalıcı saklanıyor ama bildirim gönderilmiyor. |
| **MockZanKurdRepository** | **MOCK (bilinçli)** | Supabase yapılandırması yokken offline test verisi sağlar. Tasarım gereği, sorun değil. |
| **Turnuva** | **GERÇEK ama bot tabanlı** | Çevrimiçi insan turnuvası değil; botlara karşı yerel akış. |
| **Soru açıklamaları** | **EKSİK/ŞABLON** | Hafıza notlarına göre açıklamalar hâlâ şablon düzeyinde (içerik kalitesi düşük). |
| **Crashlytics** | **GERÇEK ama koşullu** | try-catch ile sarılı; Firebase desteklemeyen platformlarda sessizce devre dışı. |

## 7. Soru Bankası Durumu

- **Aktif veri kaynağı:** Üretimde Supabase `questions` tablosu; yapılandırma yoksa kod içi `offline_question_bank.dart`.
- **Offline kod bankası:** **1.813 soru**, **~225 görselli soru referansı** (`imageAsset/imageUrl`).
- **Kategoriler (8):**
  - Ziman — 555
  - Çand — 287
  - Cografya — 251
  - Dîrok — 244
  - Edebiyat — 190
  - Muzîk — 180
  - Paradigma — 59
  - Siyaset — 47
- **Kök CSV (`zankurd_soru_bankasi_cevapli.csv`):** 120 soru — bu, geçmiş bir içe aktarma kaynağı; offline bankanın bir alt kümesi/ham hâli, canlı veri kaynağı değil.
- **Tutarsızlık notu (yalnız dokümantasyon):** CLAUDE.md'deki açıklama metni kategori kümesini hâlâ 6 ile anlatır (Ziman, Çand, Dîrok, Edebiyat, Cografya, Muzîk). Gerçek test dosyası (`test/question_bank_test.dart`) **Paradigma** ve **Siyaset**'i zaten kabul ediyor (doğrulandı) ve testler geçiyor. Yani tutarsızlık koddan değil, yalnızca CLAUDE.md metnindendir; ileride CLAUDE.md güncellenebilir (bu çalışmada içerik/test değiştirilmedi).
- Bu aşamada **toplu içerik dönüşümü yapılmadı** (kapsam dışı).

## 8. Güvenlik Notları

- **İmzalama dosyaları:** `android/key.properties` ve `android/upload-keystore.jks` diskte **mevcut**, ancak git tarafından **takip edilmiyor** (`.gitignore` ile dışlanmış). Bu dosyalar gizli imzalama materyalidir; **paylaşılmamalı, loglanmamalı, dokümana yazılmamalı, güvenli yedeklenmeli.** İçerikleri bu raporlarda yer almaz.
- **`.gitignore` güçlendirildi** (bu çalışmada): `*.apk/*.aab/*.ipa`, `*.keystore/*.p12/*.pem`, `.env/.env.*`, `.gradle/`, `/android/build/`, `/ios/Pods/` eklendi.
- **Takip edilen yapılandırma:** `android/app/google-services.json` git'te mevcut. Bu bir Firebase **istemci** yapılandırmasıdır (gizli sunucu anahtarı değildir); genelde commit edilmesi kabul görür, ancak depo herkese açık yapılacaksa gözden geçirilmesi önerilir.
- Depoda takip edilen **APK/AAB/keystore binary'si yok** (doğrulandı).

## 9. Release Öncesi Yapılacaklar

1. **Final AAB henüz üretilmedi.** ASCII build yolundan (`C:\src\zankurd_mobile`) `flutter build appbundle --release` çalıştırılmalı (Türkçe karakterli yol araçları bozabilir — bkz. BUILD_AND_TEST_NOTES.md).
2. Üretilen AAB için `jarsigner -verify` ile imza doğrulaması.
3. `dart analyze` temiz + `flutter test` tüm testler geçmeli (release öncesi son kontrol).
4. Supabase SQL dosyalarının (özellikle `online_multiplayer_ready.sql`) canlı projeye uygulandığının teyidi.
5. Play Console manuel adımları (Data Safety, içerik derecelendirmesi, gizlilik politikası URL'si, ekran görüntüleri, sürüm notları).
6. (Opsiyonel iyileştirme) AnalyticsService ve NotificationService stub/mock olduğundan, mağaza Data Safety beyanında bunların **gerçek veri toplamadığı** dikkate alınmalı.

## 10. Tasarım Cilası Önerileri

Ayrıntılı plan için bkz. **`DESIGN_POLISH_PLAN.md`**. Özet: ana sayfa hiyerarşisi, kategori kartları tutarlılığı, quiz geri bildirim animasyonları, sonuç ekranı özet kartı, profil istatistik düzeni, ayarlar gruplaması ve boş/hata/yükleme durumlarının standardizasyonu. Tümü düşük–orta riskli, davranış değiştirmeyen iyileştirmeler.

## 11. Codex/Claude İçin Bundan Sonraki Güvenli Çalışma Kuralları

- **Yeni özellik ekleme; UI tasarımını yeniden yazma; iş mantığını bozma; büyük refactor yapma.**
- Mevcut ekranları, quiz/auth akışını, Supabase entegrasyonunu **değiştirme**.
- Kod silmeden önce gerçekten gereksiz olduğunu **doğrula**.
- **İmzalama dosyalarına dokunma:** `key.properties`, `*.jks`, `*.keystore`, `*.p12`, `*.pem`, `.env` — kopyalama/loglama/ifşa etme.
- Soru bankasını **toplu dönüştürme**; içerik değişikliği gerekiyorsa önce rapor yaz.
- Veriye repository soyutlaması üzerinden eriş (`ZanKurdRepository`), doğrudan Supabase/Mock'a yazma.
- Lint için **`dart analyze`** kullan (`flutter analyze` bu ortamda Türkçe-İ yol hatası nedeniyle çöker).
- Build öncesi **TMP/TEMP** ayarla ve mümkünse **ASCII build yolu** kullan.
- Proje iletişimi ve dokümanlar **Türkçe**.
