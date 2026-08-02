# ZanKurd — Yayın Hazırlık Denetimi (Aşama 1: Kanıtlı, Salt Okunur)

**Denetim tarihi:** 2026-08-01 / 2026-08-02 (yerel saat)
**Depo:** `/Users/kocer/Projects/zankurd`
**Branch:** `main` (origin/main'in 243 commit önünde)
**HEAD:** `5c79000513e1148b55588dabe0ed923f833b4cb3`
**Son commit:** `5c79000 feat: finalize beta hardening and live question quality`
**Başlangıç worktree durumu:** temiz (`git status --short --branch` → `## main...origin/main [ahead 243]`, başka satır yok)

> Bu denetim **salt okunurdur**. Hiçbir uygulama kaynağı, migration, yapılandırma
> veya imza ayarı değiştirilmemiştir. Yazılan tek şey `docs/release_audit/2026-08-01/`
> ve `audit_artifacts/release_audit_2026-08-01/` altındaki rapor/kanıt dosyaları ile
> derleyicilerin ürettiği takip edilmeyen `build/` çıktılarıdır.

---

## 1. Yönetici özeti

ZanKurd, denetlenen sürümde **teknik olarak olgun ve mağaza politikalarına büyük
ölçüde bilinçli biçimde hazırlanmış** bir üründür. 1302 testin tamamı geçiyor,
`flutter analyze` sıfır bulgu veriyor, iOS release derlemesi sorunsuz üretiliyor,
Android `targetSdk 36` gereksinimi bugünden karşılanıyor ve 16 KB sayfa boyutu
uyumu ELF düzeyinde doğrulanıyor. Hesap silme, abonelik açıklamaları, UGC
bildir/engelle mekanizmaları ve gizlilik manifesti **gerçekten uygulanmış** —
yalnız iddia edilmiş değil.

Buna karşılık **bugün mağazaya gönderilemez**. Dört somut engel var:

0. **Üretim FTP şifresi git geçmişinde açık metin duruyor ve döndürülmemiş.**
   Projenin kendi commit notu bunu yazıyor. Tek P0 budur ve kapsamı
   mağazadan bağımsızdır — zankurd.com barındırma hesabı risk altındadır.
1. **Android release ikili üretilemiyor.** Bu makinede imzalama anahtarı yok;
   `flutter build appbundle --release` kasıtlı bir güvenlik kapısıyla duruyor.
   Bu bir kod kusuru değil, sahip/hesap düzeyinde eksik bir varlıktır — ama
   AAB olmadan Play'e yükleme yapılamaz.
2. **iPad düzeni bitmemiş, buna rağmen iPad destekleniyor.** `TARGETED_DEVICE_FAMILY
   = "1,2"` olduğu için Apple uygulamayı iPad'de inceleyecek ve iPad ekran
   görüntüsü zorunlu olacak. Gerçek iPad Pro 13" simülatöründe alınan ekran
   görüntüleri, telefon düzeninin tablete gerilmiş hâlini gösteriyor.
3. **CI bugün kırmızı.** `dart format` 23 dosyada başarısız, soru kalitesi
   kapısı `exit 1` veriyor. İkisi de yayın öncesi "yeşil CI" iddiasını geçersiz
   kılıyor.

### Beş readiness kararı

| Alan | Karar | Gerekçe (özet) |
|---|---|---|
| CODE QUALITY READINESS | `NOT READY` | Açık P0 (geçmişteki üretim sırrı) + `dart format` 23 dosyada ve soru kalitesi kapısı başarısız → CI kırmızı. analyze temiz ve 1302/1302 test geçiyor. |
| ANDROID BINARY READINESS | `BLOCKED / NOT FULLY VERIFIED` | Release AAB/APK üretilemedi (keystore yok). targetSdk 36 ✓, 16 KB ELF ✓, ama imzalı ikili ve gerçek 16 KB cihaz testi yapılamadı |
| IOS BINARY READINESS | `NOT READY` | `flutter build ios --release --no-codesign` başarılı (52 MB), privacy manifest paket içinde, 1024 ikonda alpha yok; ancak iPad düzeni bitmemiş, `DEVELOPMENT_TEAM` yok ve imzalı arşiv doğrulanmadı |
| GOOGLE PLAY CONSOLE SUBMISSION READINESS | `NOT READY` | AAB yok; Advertising ID beyanı çelişkili; native debug symbols yapılandırılmamış; hesap düzeyi kalemler doğrulanamadı |
| APP STORE CONNECT SUBMISSION READINESS | `NOT READY` | iPad düzeni + iPad ekran görüntüleri eksik; App Privacy cevapları ve demo hesap hesap düzeyinde doğrulanamadı |

**Bağımsız olarak doğruladığım bulgu sayıları:** P0: **1** · P1: **4** · P2: **9** · P3: **5**

Bunlara ek olarak, aynı depoda 11 paralel salt-okunur analiz ajanı çalıştırıldı ve
**~110 ek aday bulgu** üretti. Bunların tamamı bu turda tek tek doğrulanmadı;
doğruladıklarım yukarıdaki sayıya dahildir, kalanlar **Ek A**'da ayrı ve açıkça
"bağımsız doğrulanmadı" etiketiyle listelenmiştir. Ek A, kendi başına bulgu
değil, **bir sonraki turun doğrulama kuyruğudur**.

---

## 2. Aşama 0 — Git ve ortam snapshot'ı

### 2.1 Git

```
pwd                     /Users/kocer/Projects/zankurd
git rev-parse --show-toplevel
                        /Users/kocer/Projects/zankurd
git status --short --branch
                        ## main...origin/main [ahead 243]
git rev-parse HEAD      5c79000513e1148b55588dabe0ed923f833b4cb3
git log -1 --oneline    5c79000 (HEAD -> main, audit/2026-07-25-live-findings)
                        feat: finalize beta hardening and live question quality
git diff --stat         (boş)
git diff --check        (boş)
git submodule status    (boş — submodule yok)
```

### 2.2 Ortam

| Bileşen | Sürüm | Not |
|---|---|---|
| macOS | 26.5.2 (25F84), darwin-arm64 | |
| Flutter | 3.44.7 · stable · rev 84fc5cbb22 | `flutter doctor -v` → **No issues found** |
| Dart | 3.12.2 (stable) | |
| Xcode | 26.6 (17F113) | `/Applications/Xcode.app/Contents/Developer` |
| iOS SDK | 26.5 (`iphoneos26.5`) | App Store yükleme şartını karşılar |
| Android SDK | 36.0.0 · platform android-36 · build-tools 36.0.0 / 35.0.0 | `/opt/homebrew/share/android-commandlinetools` |
| Android NDK | 28.2.13676358 | |
| Java | OpenJDK 17.0.20 (Homebrew) | |
| CocoaPods | 1.17.0 | |
| Ruby | 4.0.6 | |
| Node / npm | v26.5.0 / 11.17.0 | |
| Supabase CLI | 2.109.1 | |

**Cihazlar:** iOS 26.5 simülatörleri (iPhone 17/17 Pro/17 Pro Max/17e/Air, iPad Pro
13" M5, iPad Pro 11" M5, iPad mini A17 Pro, iPad Air 13"/11" M4, iPad A16);
Android AVD `zankurd_test` ve `zankurd_test2` (android-36 · google_apis · arm64-v8a).

### 2.3 Uygulama kimliği

| Alan | Değer | Kaynak |
|---|---|---|
| version / build | `1.9.1+13` | `zankurd_mobile/pubspec.yaml:20` |
| Android applicationId | `com.zankurd.app` | `android/app/build.gradle.kts` |
| iOS bundle identifier | `com.zankurd.app` | `ios/Runner.xcodeproj/project.pbxproj:480` |
| iOS deployment target | 15.0 | `project.pbxproj:458` |
| iOS device family | **"1,2" (iPhone + iPad)** | `project.pbxproj:462` |
| Android min/target/compile SDK | **24 / 36 / 36** | `aapt2 dump badging` (aşağıda) |

Flavor / ayrı staging yapılandırması **yok**; ortam ayrımı `--dart-define`
(`SUPABASE_URL`, `REVENUECAT_API_KEY_*`) ile yapılıyor
(`lib/src/config/app_config.dart`).

---

## 3. Aşama 2 — Statik kalite, test ve build kapıları

### 3.1 Çalıştırılan komutlar ve sonuçları

| # | Komut | Exit | Sonuç | Log |
|---|---|---|---|---|
| 1 | `dart format --output=none --set-exit-if-changed lib test tool tools integration_test` | ≠0 | **VERIFIED FAIL** — 429 dosyanın 23'ü biçimsiz | `logs/tests/01_analyze_format.log` |
| 2 | `flutter analyze` | 0 | **VERIFIED PASS** — *No issues found! (4.5s)* | `logs/tests/01_analyze_format.log` |
| 3 | `flutter test` (tam paket) | 0 | **VERIFIED PASS** — **+1302 · All tests passed** · 0 skip · 0 fail | `logs/tests/02_flutter_test_full.log` |
| 4 | `flutter test tool/screenshots/screen_tour_test.dart` | 0 | **VERIFIED PASS** — 77 ekran görüntüsü üretildi | `logs/tests/03_screen_tour.log` |
| 5 | `dart run tool/question_quality/question_quality_audit.dart gate` | **1** | **VERIFIED FAIL** — *Gate source fingerprint changed* | `logs/data_quality/30_question_quality_gate.log` |
| 6 | `dart run ... question_quality_audit.dart report` | 0 | **VERIFIED PASS** — tam metrik üretildi | `logs/data_quality/32_question_quality_report.log` |
| 7 | `flutter build appbundle --release` | **1** | **BLOCKED — ACCOUNT/SIGNING** | `logs/builds/10_android_aab.log` |
| 8 | `flutter build apk --release` | **1** | **BLOCKED — ACCOUNT/SIGNING** | `logs/builds/10_android_aab.log` |
| 9 | `flutter build apk --debug` | 0 | **VERIFIED PASS** (analiz için) | `logs/builds/12_android_debug.log` |
| 10 | `flutter build ios --release --no-codesign` | 0 | **VERIFIED PASS** — `Runner.app` 52.0 MB | `logs/builds/11_ios_release.log` |
| 11 | `flutter build ios --simulator --debug` | 0 | **VERIFIED PASS** | `logs/builds/15_ios_simulator_build.log` |
| 12 | `flutter build web --release` | 0 | **VERIFIED PASS** — `build/web` 51 MB | `logs/builds/17_web_release.log` |
| 13 | `zipalign -c -P 16 -v 4` (debug APK) | 0 | **VERIFIED PASS** — *Verification successful* | `logs/builds/13_16kb_elf_alignment.log` |
| 14 | `llvm-readelf -lW` (tüm `.so`) | 0 | **VERIFIED PASS** — bkz. §3.4 | `logs/builds/13_16kb_elf_alignment.log` |

### 3.2 Test kapsamı

- **222 test dosyası** (`test/` + `integration_test/`), toplam **1302 test**.
- **0 skipped**, **0 flaky**, **0 timeout** gözlendi (tek koşu, `--concurrency=4`).
- `integration_test/` (2 dosya: `app_flows_test.dart`, `performance_test.dart`)
  cihaz gerektirir; bu turda **NOT RUN — cihazda koşturulmadı**.
- Testler yalnız birim değil: erişilebilirlik (`accessibility_guideline_test`,
  `large_text_overflow_test`, `contrast_policy_test`), mağaza uyumu
  (`paywall_compliance_test`, `release_checklist_contract_test`), güvenlik
  (`supabase_security_hardening_contract_test`, `xp_server_authority_test`) ve
  içerik kalitesi (`all_banks_quality_test`, `question_language_policy_test`)
  kapılarını da içeriyor. Bu, projedeki en güçlü kalite sinyalidir.

**Projenin kendi yayın sözleşmesi.** `test/release_readiness_contract_test.dart`
yayın için gereken davranışları doğrudan test olarak sabitlemiş ve **hepsi
geçiyor**:

| Sözleşme | Ne koruyor |
|---|---|
| *"Android excludes account data from backup and device transfer"* | Yedekleme kurallarının token/hesap verisini dışarıda bırakması |
| *"sign-out clears every account-linked local progress store"* | Çıkışta cihazda başka kullanıcıya ait ilerleme kalmaması |
| *"forward-only release hardening migration closes direct writes"* | İstemcinin doğrudan tablo yazımının kapalı kalması |
| *"ödül RPC'leri yalnız sunucuda doğrulanabilen olgulara dayanır"* | Ekonomi bütünlüğü |
| *"iOS privacy manifest matches analytics and purchase SDK usage"* | Manifest–SDK tutarlılığı |
| *"unverified contest and XP claims cannot mint server rewards"* | Sahte ödül basımının engellenmesi |
| *"account deletion releases contributor foreign keys first"* | Hesap silmenin FK yüzünden yarıda kalmaması |
| *"leaderboard limit"* → `least(greatest(p_limit, 1), 100)` | Liderlik sorgusunun sınırlanması |

Bu sözleşmeler, denetimde bağımsız olarak doğruladığım güvenlik duruşunu
(secret yok, publishable anahtar, sunucu-yetkili ödüller, hesap silme) kod
tarafında da kalıcı kılıyor.

### 3.3 Android release build — BLOCKED

```
* What went wrong:
Release signing configuration is missing or incomplete. Expected
android/key.properties with non-empty fields: storeFile, storePassword,
keyAlias, keyPassword; storeFile must point to an existing keystore.
Missing or invalid: android/key.properties. ... The release build was
stopped for security and will not fall back to debug signing.
```

`android/app/build.gradle.kts:24-52` bilinçli bir kapı kuruyor: release görevi
istendiğinde `key.properties` eksikse **debug imzasına düşmek yerine** derlemeyi
durduruyor. Bu **doğru bir tasarım** — debug imzalı bir AAB'nin Play'e gitmesini
imkânsız kılıyor. Engel, bu makinede keystore'un bulunmamasıdır (`android/key.properties`
yok, `git check-ignore` ile yoksayılıyor, repoda hiç izlenmemiş).

**Sonuç:** Release AAB `BLOCKED — ACCOUNT/SIGNING`. Kök neden kodda değil,
sahip tarafındaki imzalama varlığında.

### 3.4 Android 16 KB sayfa boyutu — ELF düzeyinde PASS, cihazda NOT RUN

İki bağımsız kontrol yapıldı.

**(a) Zip hizalama** — debug APK üzerinde `zipalign -c -P 16 -v 4` →
`Verification successful` (exit 0).

**(b) ELF `PT_LOAD` `p_align`** — asıl gereksinim budur; `zipalign` bunu ölçmez.
`llvm-readelf -lW` (NDK 28.2) ile:

| Kaynak | ABI | Kütüphane | LOAD align | Karar |
|---|---|---|---|---|
| **Release engine** (Flutter cache `flutter.jar`) | arm64-v8a | `libflutter.so` | `0x10000` (64 KB) | **PASS** |
| **Release engine** | x86_64 | `libflutter.so` | `0x10000` | **PASS** |
| Release engine | armeabi-v7a | `libflutter.so` | `0x10000` | PASS (32-bit, kapsam dışı) |
| Debug APK | arm64-v8a | `libdartjni.so` | `0x4000` (16 KB) | **PASS** |
| Debug APK | arm64-v8a | `libdatastore_shared_counter.so` | `0x4000` | **PASS** |
| Debug APK | x86_64 | `libdartjni.so`, `libdatastore_shared_counter.so` | `0x4000` | **PASS** |
| Debug APK | arm64-v8a | `libVkLayer_khronos_validation.so` | `0x10000` | PASS (yalnız debug) |

16 KB uyumsuz **hiçbir** kütüphane veya plugin bulunmadı.

**Dürüst sınırlar:**
- Release AAB üretilemediği için release ikilisinin **kendi içinden** çıkarılan
  `.so` kümesi doğrulanamadı. Bunun yerine (i) release Flutter engine `.so`'ları
  doğrudan Flutter cache'inden, (ii) plugin `.so`'ları debug APK'dan alındı.
  Plugin `.so`'ları AAR'lardan hazır geldiği için debug/release'te aynıdır;
  engine `.so`'su farklıdır ve release varyantı ayrıca doğrulanmıştır.
- **Gerçek 16 KB cihaz testi yapılmadı.** Kurulu tek sistem imajı
  `android-36/google_apis/arm64-v8a` ve emülatörde `getconf PAGE_SIZE` → **4096**.
  16 KB sayfa boyutlu sistem imajı kurulu değil.
  → Çalışma zamanı 16 KB doğrulaması **NOT RUN — TOOL MISSING (16 KB system image)**.

### 3.5 Android manifest ve SDK seviyeleri (aapt2, ikiliden okundu)

```
package: name='com.zankurd.app' versionCode='13' versionName='1.9.1'
         compileSdkVersion='36' compileSdkVersionCodename='16'
targetSdkVersion:'36'
native-code: 'arm64-v8a' 'armeabi-v7a' 'x86_64'
application-label:'ZanKurd'   (ve 90+ yerel ayarda aynı)
launchable-activity: com.zankurd.app.MainActivity
uses-feature: android.hardware.faketouch    (yanlış cihaz filtreleme yok)
```

Google Play'in **31 Ağustos 2026** tarihli API 36 gereksinimi
(kaynak: <https://developer.android.com/google/play/requirements/target-sdk>,
erişim 2026-08-01) **bugünden karşılanıyor**. 64-bit ABI'ler mevcut.

**Birleştirilmiş manifeste SDK'lardan gelen izinler** (uygulamanın kendi
manifestinde yazmayan, ama ikiliye giren):

| İzin | Kaynak | Etki |
|---|---|---|
| `com.google.android.gms.permission.AD_ID` | firebase_analytics | **Play Data Safety'de Advertising ID beyanı zorunlu** |
| `ACCESS_ADSERVICES_ATTRIBUTION`, `ACCESS_ADSERVICES_AD_ID` | GoogleAdsOnDeviceConversion | Privacy Sandbox ilişkilendirme |
| `com.android.vending.BILLING` | purchases_flutter (RevenueCat) | Play Billing beyanı |
| `BIND_GET_INSTALL_REFERRER_SERVICE` | Play Install Referrer | |
| `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `VIBRATE` | connectivity_plus / bildirimler | |

Uygulamanın kendi manifesti yalnız `INTERNET`, `RECEIVE_BOOT_COMPLETED`,
`POST_NOTIFICATIONS` istiyor — minimal ve gerekçeli. Riskli/kısıtlı izin yok.

### 3.6 iOS yapılandırma

Üretilen `build/ios/iphoneos/Runner.app` (52.0 MB) üzerinden doğrulandı:

| Alan | Değer | Karar |
|---|---|---|
| `CFBundleIdentifier` | `com.zankurd.app` | PASS |
| `CFBundleShortVersionString` / `CFBundleVersion` | `1.9.1` / `13` | PASS |
| `CFBundleDisplayName` | `ZanKurd` | PASS |
| `MinimumOSVersion` | 15.0 | PASS |
| Mimari | arm64 (tek) | PASS |
| `ITSAppUsesNonExemptEncryption` | `false` | PASS — export compliance sorusu otomatik yanıtlanır |
| `PrivacyInfo.xcprivacy` | **paket kökünde mevcut** | PASS |
| Üçüncü taraf privacy manifestleri | **30 adet** (Firebase, RevenueCat, GoogleUtilities, image_picker, share_plus, url_launcher, sqflite, connectivity_plus, …) | PASS |
| Kullanım açıklamaları | yalnız `NSPhotoLibraryUsageDescription` | **PASS** — `image_picker` sadece `ImageSource.gallery` kullanıyor (`avatar_editor_screen.dart:123`), kamera yolu yok |
| AppIcon | 21 boyut; `Icon-App-1024x1024@1x.png` → `hasAlpha: no` | PASS — alpha kanalı reddi riski yok |
| `TARGETED_DEVICE_FAMILY` | **"1,2"** | ⚠ iPad kapsamda — bkz. ZKR-REL-20260801-P1-002 |

Uyarı (bloklayıcı değil): `flutter build ios` çıktısında
*"The following plugins do not support Swift Package Manager for ios: flutter_tts"*.

---

## 4. Aşama 3 — Gerçek cihazda ekran ve UX denetimi

### 4.1 Gerçekten görüntülenen ekranlar

> **2026-08-02 düzeltmesi (errata E-03).** Aşağıdaki sayılar dosya sisteminden
> yeniden sayılmış ve SHA-256 ile kopya/boş kontrolü yapılmıştır: **18 benzersiz
> görüntü, 0 kopya, 0 boş dosya.** Önceki "9 + 5 + 2 = 16" dağılımı yanlıştı.

| Ortam | Cihaz / OS | Yöntem | Ekran sayısı |
|---|---|---|---|
| **Android (gerçek emülatör)** | Pixel 7 AVD · **Android 16 / API 36** · arm64-v8a · 1080×2400 | debug APK kurulup çalıştırıldı, `adb screencap` | **13** |
| **iOS (gerçek simülatör)** | iPhone 17 · **iOS 26.5** · 402×874 pt | simulator build kurulup çalıştırıldı | **3** |
| **iPadOS (gerçek simülatör)** | **iPad Pro 13" (M5)** · iOS 26.5 | simulator build kurulup çalıştırıldı | **2** |
| Test-renderer (tamamlayıcı) | Flutter test harness | `screen_tour_test.dart` | **77** |

Gerçek cihazda görüntülenen toplam: **18 ekran görüntüsü**; test-renderer ile
birlikte **95**. Test-renderer çıktıları `audit_artifacts/.../screenshots/tour_render/`
altında ve **gerçek cihaz doğrulamasının yerine değil, kapsam genişletici olarak**
kullanılmıştır (CLAUDE.md'de belirtildiği gibi emoji ve `CustomPainter` metni test
koşucusunda kutu çıkabilir — bu iki sınıf simülatör/emülatörden doğrulandı).

### 4.2 Doğrulananlar (gerçek cihazda)

- **Açılış ve kararlılık.** Her iki platformda uygulama açıldı, hiçbir koşuda
  crash/ANR/blank screen olmadı. `adb logcat` içinde `FATAL` / `AndroidRuntime` /
  `E/flutter` kaydı **yok**.
- **Kurmancî tipografi.** `ê î û ş ç` ve `Î`/`Û` gerçek cihazda doğru render
  ediliyor: *"Kurmancî hîn bibe, pêş bikeve"*, *"10 kategorî — ziman, dîrok, çand…"*,
  *"Bi xêr hatî ZanKurdê!"*, *"Zincîra xwe biparêze"*. Mojibake yok.
- **Türkçe tipografi.** *"İyi Geceler, Oyuncu!"*, *"Günün dersi"*, *"Sıralama"*,
  *"Doğruluk"* — `İ/ı/ğ/ş/ç/ö/ü` doğru.
- **Safe area / edge-to-edge.** iPhone 17'de Dynamic Island ve home indicator
  alanları doğru bırakılıyor; Android 16'da status/navigation bar çakışması yok.
- **Karanlık tema.** iOS'ta koyu tema tam ve tutarlı; kontrast korunuyor.
- **Emoji.** Onboarding kartındaki ☀ emoji gerçek cihazda düzgün çiziliyor
  (test koşucusundaki kutu sorunu cihazda yok — CLAUDE.md notu doğrulandı).
- **Çevrimdışı dayanıklılık.** `svc wifi disable` + `svc data disable` ile tam
  çevrimdışı: uygulama çökmedi, onboarding ve yerel akışlar çalışmaya devam etti,
  logcat'te istisna yok.
- **Boş durumlar.** Yeni kullanıcıda `Sıralama —`, `Toplam Puan —` gibi alanlar
  ham `null`/`0` yerine anlamlı tire ile gösteriliyor.

### 4.3 Erişilebilirlik — dinamik yazı tipi (gerçek iOS cihazı)

`xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`
(iOS'un en büyük erişilebilirlik kademesi) uygulandıktan sonra Profil ekranı:

- Başlık, isim, rozet, istatistik kartları **büyüyor ve yeniden akıyor**;
- `0 / 1000 XP` → `0 / 1000 …` biçiminde **ellipsis ile kısalıyor**, taşmıyor;
- Hiçbir kart kırpılmıyor, hiçbir metin kesilmiyor, alt gezinme bozulmuyor.

**VERIFIED PASS.** Kanıt: `screenshots/ios/02_profile_dark_xxxl_text.png`,
`03_profile_light_xxxl_text.png`.

Gözlem (kusur değil): sistem görünümü `light`'a alındığında uygulama koyu temada
kaldı — tema uygulama içi `ThemeProvider` ile yönetiliyor, sistem temasını takip
etmiyor. Bilinçli bir ürün kararı; başlıkta ay/güneş anahtarı mevcut.

### 4.4 iPad — bulunan kusur

`TARGETED_DEVICE_FAMILY = "1,2"` olduğu için uygulama iPad'de de çalışıyor ve
Apple onu iPad'de inceleyecek. iPad Pro 13" (M5) simülatöründe iki ekran:

- **Onboarding:** hero kartı ~1400 pt genişliğinde boş yeşil bir dikdörtgene
  dönüşüyor, ortasında küçük bir ikon; kart ile başlık arasında ~400 pt boşluk.
- **İsim kapısı:** turuncu başlık tam genişlikte, içeriği sol ~%30'a sıkışmış;
  ortada küçük bir kart, altında ~600 pt tamamen boş alan.

**Kök neden (kodda yazılı):** `lib/src/widgets/responsive_wrapper.dart`
`maxContentWidth = 1200` ve `wideThreshold = 600`. iPad Pro 13" dikey mantıksal
genişliği ~1032 pt olduğu için sarmalayıcı devreye giriyor ama **1200 sınırı hiç
bağlamıyor** — içerik yine tam genişliğe yayılıyor. Sınıfın kendi belgesi durumu
açıkça kabul ediyor:

> *"Gerçek iki sütunlu tablet düzeni kapsamlı bir tasarım işi; izole bir sprint
> olarak planlanmalı (M-12)."*

Ayrıca `ResponsiveWrapper` yalnız 3 dosyada geçiyor (`main.dart`, `coach_mark.dart`,
kendi tanımı) — yani global olarak uygulanıyor, ekran bazlı tablet düzeni yok.

Kanıt: `screenshots/ios/10_ipad_pro13_launch.png`, `11_ipad_after_skip.png`.

### 4.5 Yapılamayanlar (dürüst kayıt)

| Kontrol | Durum | Sebep |
|---|---|---|
| İki istemcili çevrimiçi oda maçı | `NOT RUN` | Bu turda iki cihazlı canlı oturum kurulmadı; üretim verisi mutasyonu gerektirir |
| Kayıt / giriş / şifre sıfırlama / e-posta doğrulama uçtan uca | `BLOCKED — NO SAFE TEST ENVIRONMENT` | Ayrı dev/test Supabase projesi yok; üretimde hesap oluşturmak mutasyondur |
| Hesap silme uçtan uca | `BLOCKED — NO SAFE TEST ENVIRONMENT` | Gerçek hesap silmek geri alınamaz |
| Satın alma / abonelik / restore | `BLOCKED — ACCOUNT/SIGNING` | Sandbox App Store hesabı ve imzalı ikili gerekir |
| `integration_test/` cihazda | `NOT RUN` | Bu turda koşturulmadı |
| Gerçek 16 KB sayfa boyutlu cihaz | `NOT RUN — TOOL MISSING` | 16 KB sistem imajı kurulu değil |
| Release modda performans ölçümü | `NOT RUN` | Android release ikili üretilemedi |

---

## 5. Aşama 4 — Soru bankası ve içerik kalitesi

Bütün sayılar **bu denetimde yeniden hesaplanmıştır**; önceki raporlardan
kopyalanmamıştır. Kullanılan salt okunur betikler
`audit_artifacts/.../logs/data_quality/` altında saklanmıştır.

### 5.1 Kapsam ayrımı — kritik nokta

Depodaki soru altyapısı **50 kaynak** tanıyor, ama bunların çoğu aday havuzu,
karantina ve tarihsel anlık görüntüdür. **Uygulamaya giren** kaynak beştir.

| Kapsam | Fiziksel kayıt | Kanonik benzersiz | Blocker | Critical | Warning |
|---|---:|---:|---:|---:|---:|
| **Gate (uygulamaya giren)** | **1832** | **1771** | **0** | **0** | 1856 |
| Report (50 kaynağın tümü) | 91 385 | 37 461 | 59 867 | 6 948 | 77 108 |

> Bu ayrım yapılmazsa tablo felaket gibi görünür. Gerçek şu: **59 867 blocker'ın
> hiçbiri uygulamaya girmiyor**; hepsi `candidate_pool`, `quarantine` ve
> `historical_snapshot` rolündeki dosyalarda. Yayınlanan bankada blocker ve
> critical sayısı **sıfır**.

Rol dağılımı: `quarantine` 20 000 · `candidate_pool` 17 471 ·
`historical_snapshot` 51 849 · `publish_candidate` 233 ·
**`runtime_primary` 1428** · **`runtime_secondary` 404**.

### 5.2 Yayınlanan bankanın doğrudan ölçümü

`assets/data/*.json` üzerinde bağımsız python analizi (1787 JSON kaydı +
45 `curated_question_bank.dart` = 1832):

| Ölçüt | Sonuç | Karar |
|---|---|---|
| Boş soru metni | **0** | PASS |
| Şıkkı eksik soru | **0** | PASS |
| Tekrarlanan şık | **0** | PASS |
| Boş şık | **0** | PASS |
| Tam kopya soru metni (normalize) | **0** | PASS |
| Encoding / mojibake | **0** | PASS |
| Placeholder / test sorusu | **0** | PASS |
| Açıklaması olmayan | 15 / 1787 (%0.8) | PASS (ihmal edilebilir) |
| Görselli soru | 138 | — |
| Şık sayısı dağılımı | 4 şık: 1214 · 2 şık: 568 · **3 şık: 4** · **5 şık: 1** | ⚠ P3 tutarsızlık |

**Doğru cevap konumu (yalnız yayınlanan banka, n=1779):**

| Tip | A | B | C | D |
|---|---:|---:|---:|---:|
| `multipleChoice` (n=1074) | %24.1 | %24.2 | %23.8 | %27.8 |
| `visual` (n=137) | %20.4 | %22.6 | %28.5 | %28.5 |
| `trueFalse` (n=568) | %52.6 | %47.4 | — | — |

Dört şıklı sorularda dağılım **neredeyse tekdüze** — `e6cb01b` commit'indeki
konum dengeleme çalışması işe yaramış. (Uyarı: `report` kapsamındaki
A %45.79 / D %11.70 rakamı **aday havuzlarını da içerir**, uygulamayı temsil etmez.)

**Uzunluk yanlılığı:** doğru şık tek başına en uzun olan soru oranı
**227/1211 = %18.7**. Dört şıkta rastgele beklenti ~%25 olduğuna göre
**yanlılık yok** (hatta beklentinin altında). PASS.

**Kategori dağılımı (yayınlanan):** Ziman 267 · Cografya 226 · Dîrok 202 ·
Çand 198 · Muzîk 197 · Edebiyat 185 · Siyaset 177 · Paradigma 162 ·
Teknolojî 102 · Sînema 71 → 10 kategori, makul dengeli.
**Zorluk:** 1→249, 2→363, 3→495, 4→417, 5→263 — çan eğrisi, sağlıklı.

### 5.3 Yanlış alarm — kaydedilmiştir

İlk taramada "doğru cevabı şıklarda bulunmayan 8 soru" işaretlendi. İncelendi:
sekizi de `type: wordOrdering`. Bu tipte `answers` **kelime havuzu**,
`correctAnswer` ise **kurulacak cümledir** — şema doğrudur.
`lib/src/screens/quiz/word_ordering_widget.dart:58` (`final rawWords =
widget.question.answers;`) bunu doğruluyor. **Kusur değildir.**

### 5.4 Soru kalitesi kapısının başarısızlığı — kök neden

```
question-quality: sources=5 reportPhysical=1832 reportCanonical=1771 ...
Gate source fingerprint changed; baseline metrics were not accepted.   [exit 1]
```

`tool/question_quality/baseline.json` beş kaynağın SHA-256 parmak izini
sabitliyor. Üçü değişmiş:

| Kaynak | Durum |
|---|---|
| `assets/data/community_questions.json` | **CHANGED** |
| `assets/data/editorial_questions.json` | **CHANGED** |
| `assets/data/offline_questions.json` | **CHANGED** |
| `assets/data/sentence_building_questions.json` | MATCH |
| `lib/src/data/curated_question_bank.dart` | MATCH |

Git zaman çizelgesi kesin: üç JSON `e6cb01b` (**2026-08-01**, *"fix(sorular):
cevap konumu yanlılığını…"*) ile değişti; `baseline.json` en son `c901521`
(**2026-07-31**) ile güncellendi. Yani **içerik düzeltildi, baseline tazelenmedi**.

Bu bir veri kusuru değil, **kapının kendisinin devre dışı kalmasıdır**: CI'nin
"soru kalitesi regresyonu" adımı bugün her push'ta kırmızı döner ve gerçek bir
regresyon oluşsa da aynı hatayla maskelenir.

---

## 6. Aşama 5 — Güvenlik, backend ve ekonomi bütünlüğü

### 6.1 Secret taraması — güncel dosyalar temiz, git geçmişi değil

> **2026-08-02 düzeltmesi (bkz. `AUDIT_ERRATA_2026-08-02.md` E-01).** Bu bölüm
> ilk yazıldığında "temiz" diyordu ve §8'deki P0-001 ile çelişiyordu. Çelişkinin
> sebebi, buradaki taramanın **dosya adına** dayanmasıydı (`*.env*`,
> `key.properties`, `*.jks`, `*.p8`); sır ise `deploy_ftp.sh` betiğinin
> **içindeydi** ve ancak içerik tabanlı arama (`git log -S`) ile bulundu.
> Doğru ayrım şudur:
>
> | Kapsam | Durum |
> |---|---|
> | Güncel HEAD + takip edilen güncel dosyalar | **TEMİZ** |
> | Git geçmişi | **KİRLİ** — `deploy_ftp.sh:3-5` @ `e8e358a^` |
> | Aktif kimlik bilgisi riski | **GİDERİLDİ** — parola 2026-08-02'de döndürüldü (owner-confirmed) |
> | Geçmiş kalıntısı | **AÇIK** — history scrub ertelendi |
>
> Aşağıdaki tablo ve sonuç cümlesi **yalnız güncel dosyalar** için geçerlidir.

| Dosya | İzleniyor mu? | Karar |
|---|---|---|
| `.env.deploy` | **Hayır** — `.gitignore:57 (.env.*)` | PASS |
| `.env.web.release.json` | **Hayır** — `.gitignore:57` | PASS |
| `android/key.properties` | **Hayır** — `android/.gitignore:13` | PASS (dosya yok) |
| `.env.deploy.example`, `.env.*.example.json` | Evet | PASS — şablon, sır içermez |
| `android/app/google-services.json` | Evet | PASS — istemci yapılandırması, sır değil |
| `lib/firebase_options.dart` | Evet | PASS — istemci yapılandırması |

Git geçmişi taraması (`git log --all --name-only -- "*.env*" "*key.properties*"
"*.jks" "*.p8" "*serviceAccount*"`) yalnız **`.example`** dosyalarını gösteriyor;
gerçek bir sır hiç commit edilmemiş.

**Supabase anahtarı doğru sınıflandırılmış.** `lib/src/config/app_config.dart:9`
gömülü değer `sb_publishable_…` — Supabase'in yeni **publishable (public)**
anahtar biçimi. Bu istemcide bulunması gereken bir değerdir, `service_role`
sızıntısı **değildir**. RevenueCat anahtarları `String.fromEnvironment` ile
derleme zamanında geliyor; repoda gömülü anahtar yok.

**Sonuç: güncel takip edilen dosyalarda P0 secret bulgusu yok.** Git geçmişindeki
doğrulanmış üretim kimlik bilgisi için bkz. `ZKR-REL-20260801-P0-001` (§8).

### 6.2 Supabase / backend

105 dosyalık `supabase/` dizini ve `supabase/applied.md` incelendi. `applied.md`
alışılmadık derecede iyi tutulmuş bir uygulama günlüğü: her migration için
canlıda olup olmadığı, ne zaman ve nasıl uygulandığı, hangi sorgunun neyi
doğruladığı yazılı. Son bir ayda uygulanan sertleştirmeler arasında:

- `2026-07-31_tournament_score_authority.sql` — istemcinin bildirdiği turnuva
  skoru sınırsız kabul ediliyordu (`p_score = 2147483647` ile sınırsız coin);
  tavan getirildi.
- `2026-07-31_exposure_hardening.sql` — `correct_option` taşıyan iki yedek tablo
  silindi; `search_profiles`te LIKE metakarakter kaçışı; `profiles.fcm_token`
  üzerinde kolon bazlı `revoke select`.
- `2026-07-31_chat_moderation.sql` — `blocked_users` / `message_reports`
  tabloları, `chat_message_is_clean` süzgeci + BEFORE INSERT tetikleyicisi,
  `report_room_message` / `block_player` / `unblock_player` RPC'leri;
  `room_messages` okuması `USING (true)`den oda üyeliğine çekildi; `sender_id`
  sunucuda yeniden yazılıyor (sohbette kimlik taklidi kapatıldı).
- `2026-08-01_function_search_path_hardening.sql` — 21 `security definer`
  fonksiyonun `search_path`'i sabitlendi.
- `2026-08-01_room_messages_policy_hardening.sql`, `..._security_advisor_hardening.sql`.

**İstemci–sunucu çapraz doğrulaması yapıldı:**
`applied.md`, `2026-08-01_room_question_advance.sql` satırında
**"BEKLİYOR — canlı çok oyunculu maçları etkiliyor"** notunu taşıyor. Kodda
kontrol edildi: istemci **`advance_room_question` RPC'sini çağırıyor**
(`lib/src/screens/quiz_screen.dart:1260`) ve bunu koruyan bir test var
(`test/room_question_advance_test.dart:48,79,124`). Yani düzeltme tamamlanmış,
**manifest notu bayat**. (P3 belge tutarsızlığı.)

UGC moderasyonu istemci tarafında da bağlı:
`supabase_zankurd_repository.dart:661` `report_room_message`,
`:674` `block_player`, `:685` `unblock_player`, `:696` `blocked_users`.

**Doğrulanamayan alan:** `applied.md` çok sayıda satırı `?` ile işaretliyor
("tek tek doğrulanmadı"). Uzak şema ile yerel migration'lar arasındaki drift
bu turda **INCONCLUSIVE** — canlı veritabanına salt okunur bağlanma bu denetimin
kapsamı dışında tutuldu (üretim ortamı).

### 6.3 Sanal ekonomi, IAP ve rastgele ödül

| Soru | Cevap | Kanıt |
|---|---|---|
| Gerçek para ile ne satılıyor? | **Yalnız `premium` aboneliği** (RevenueCat entitlement) | `premium_service.dart:50` `_entitlementId = 'premium'` |
| Coin paketi / tüketilebilir IAP var mı? | **Hayır** | `premium_service.dart` içinde coin ürünü yok |
| Coin nasıl elde ediliyor? | **Kazanılarak** | `strings.dart:1219` `K.earnCoins` → *"Coin kazan" / "Zêr qezenc bike"* |
| Mağaza ne satıyor? | `spin_wheel_extra`, `avatar_frame_gold`, `avatar_frame_neon`, `profile_badge_vip` — **coin karşılığı** | `shop_screen.dart:157-187` |
| Çark gerçek parayla alınabiliyor mu? | **Hayır** | Yukarıdaki zincir |

**Sonuç — Apple 3.1.1 loot box:** Kural *"randomized virtual items **for purchase**"*
için geçerlidir. Çark ne doğrudan ne de satın alınmış para ile alınabildiğinden
**olasılık açıklama zorunluluğu `NOT APPLICABLE`**.

**Abonelik uyumu (Apple 3.1.2 / Play):** Hepsi uygulanmış **ve testle korunuyor**
(`test/paywall_compliance_test.dart`):
- `Restore Purchases` mevcut ve erişilebilir (`paywall_screen.dart:79, 590`);
- Otomatik yenileme metni iki dilde, *"24 saat"* ve *"iptal"* geçiyor
  (`strings.dart:1755-1764`, testle sabitlenmiş);
- Fiyatın yanında dönem eki (`/ay`, `/yıl`, `/hafta`, `/meh`, `/sal`);
- Paywall üzerinde `LegalLinksRow` (gizlilik + koşullar).

**Ekonomi bütünlüğü:** `2026-07-29_client_reward_authority_fix.sql` ve
`2026-07-31_tournament_score_authority.sql` ile istemci-yetkili ödül yolları
kapatılmış; XP ve öğrenme ilerlemesi bilinçli olarak **cihaz-yerel** tutuluyor
(`applied.md`). Sunucu tarafı doğrulama canlı sorguyla yapılamadığı için
**INCONCLUSIVE** olarak işaretlenmiştir.

### 6.4 UGC ve sosyal özellikler — Apple 1.2 tam karşılanıyor

Resmî gereksinim (kaynak: <https://developer.apple.com/app-store/review/guidelines/>,
erişim 2026-08-01) dört madde ister:

| Apple 1.2 gereksinimi | Durum | Kanıt |
|---|---|---|
| Uygunsuz içeriği **süzme** | ✅ | `chat_message_is_clean` + `room_messages` BEFORE INSERT tetikleyicisi (`2026-07-31_chat_moderation.sql`); `lib/src/services/chat_moderation_policy.dart` |
| İçeriği **bildirme** | ✅ | `report_room_message` RPC (`supabase_zankurd_repository.dart:661`) |
| Kötüye kullananı **engelleme** | ✅ | `block_player` / `unblock_player` (`:674`, `:685`), `blocked_users` sunucu süzgeci |
| **Yayınlanmış iletişim** bilgisi | ✅ | `nisebinbawer47@gmail.com` — terms.html ve delete-account.html üzerinde canlı doğrulandı |

UGC yüzeyi: oda sohbeti, görünen ad, avatar, oda kodu, önerilen sorular
(`suggest_question_screen.dart`, `suggested_questions` moderasyon tablosu ile).

---

## 7. Aşama 6 — Gizlilik ve yasal bağlantılar

`ZANKURD_PRIVACY_DATA_MAP.md` dosyasına bakınız. Burada yalnız canlı doğrulama:

| URL | Durum | İçerik |
|---|---|---|
| `https://www.zankurd.com/privacy.html` | **VERIFIED — canlı** | Gerçek politika; Supabase / Firebase / RevenueCat açıkça sayılıyor; hesap silme yolu tarif ediliyor. **İletişim e-postası yok.** |
| `https://www.zankurd.com/terms.html` | **VERIFIED — canlı** | TR + Kurmancî; abonelik, otomatik yenileme, UGC lisansı; iletişim `nisebinbawer47@gmail.com` |
| `https://www.zankurd.com/delete-account.html` | **VERIFIED — canlı** | Uygulama içi yol + e-posta ile talep; 30 gün taahhüdü; `mailto:` bağlantısı |

Üçü de HTTPS, Play'in **herkese açık hesap silme URL'si** şartını karşılıyor.
Uygulama içi bağlantılar `AppConfig.privacyPolicyUrl` / `termsOfServiceUrl`
üzerinden `LegalLinksRow` ile açılıyor; dokunma hedefi `minWidth/minHeight: 44`
ile garanti edilmiş (`legal_links.dart`).

**Hesap silme (Apple 5.1.1(v) + destek belgesi, erişim 2026-08-01):**
Apple, *otomatik oluşturulan ("guest") hesaplar dahil* hesap oluşturan her
uygulamada uygulama içi silme ister. ZanKurd'da mevcut:
`settings_screen.dart:935` `delete-account-action` → `_confirmDeleteAccount()`
→ ilk onay diyaloğu → `_showFinalDeleteConfirmation()` **kelime yazdırarak**
ikinci onay → `repository.deleteMyAccount()` → `client.rpc('delete_my_account')`
(`supabase_zankurd_repository.dart:304-311`). `applied.md`, `delete_my_account_rpc.sql`
için canlı fonksiyonun ve yalnız `authenticated` çalıştırma yetkisinin
2026-07-29'da doğrulandığını kaydediyor. **Kod düzeyinde VERIFIED PASS**;
uçtan uca silme `BLOCKED — NO SAFE TEST ENVIRONMENT`.

---

## 8. Bulgular

Kimlik biçimi: `ZKR-REL-20260801-<seviye>-<sıra>`. Tam makine-okunur sürüm:
`ZANKURD_FINDINGS.json`.

### P0 — Mutlak release blocker

#### `ZKR-REL-20260801-P0-001` — Üretim FTP şifresi git geçmişinde açık metin; döndürülmemiş

| Alan | İçerik |
|---|---|
| **Seviye** | **P0** |
| **Platform** | Altyapı / barındırma (mağazadan bağımsız) |
| **Alan** | Secret yönetimi |
| **Durum** | `VERIFIED FAIL` |
| **Kanıt** | `git show e8e358a^:zankurd_mobile/deploy_ftp.sh` satır 3-5, üretim Hostinger hesabının **açık metin** kimlik bilgilerini içeriyor: `HOST="82.25.***.***"`, `USER="u6226*****.zankurd.com"`, `PASS="Amargi.***REDACTED***"` ve satır 20'de `--user "$USER:$PASS"`. Sır **projenin kendi commit notunda** kabul ediliyor — `e8e358a` (2026-07-24) gövdesi: *"deploy_ftp.sh içindeki açık metin FTP şifresi kaldırıldı… **Not: Sızan FTP şifresi git GEÇMİŞİNDE hâlâ mevcut — Hostinger'dan şifre değiştirilmeli.**"* |
| **Dosya** | `zankurd_mobile/deploy_ftp.sh:3-5` (commit `e8e358a^` ve öncesi); düzeltme commit'i `e8e358a` |
| **Yeniden üretim** | `git show e8e358a^:zankurd_mobile/deploy_ftp.sh \| sed -n '3,5p'` |
| **Beklenen** | Üretim kimlik bilgisi hiçbir commit'te bulunmaz |
| **Gerçek** | HEAD temiz (`deploy_ftp.sh` artık `deploy_sftp.sh`e devrediyor ve sırları gitignore'lu `.env.deploy`dan okuyor), ama **geçmişte erişilebilir durumda** |
| **Kullanıcı etkisi** | Dolaylı ama ağır: bu hesap `zankurd.com`u barındırıyor — yani **gizlilik politikası, kullanım koşulları ve hesap silme sayfalarını** sunan host. Ele geçirilirse bu yasal sayfalar değiştirilebilir veya kaldırılabilir; web sürümüne kötü amaçlı içerik konabilir. |
| **Store etkisi** | Dolaylı: mağazaya bildirilen Privacy Policy / Support / Account Deletion URL'lerinin bütünlüğü bu hesaba bağlı |
| **Güvenlik etkisi** | **Yüksek.** Canlı üretim barındırma kimlik bilgisi. Projenin kendi notu şifrenin döndürülmediğini söylüyor ve bu denetimde döndürüldüğüne dair hiçbir kayıt bulunamadı. |
| **Kök neden** | Dağıtım betiği başlangıçta kimlik bilgilerini gömülü tutuyordu; 2026-07-24'te düzeltildi fakat **yalnız ileriye dönük** — geçmiş yeniden yazılmadı ve şifre döndürülmedi. |
| **Hafifletici gerçek (doğrulandı)** | `git remote -v` → `origin` bir **yerel bundle dosyası** (`/Users/kocer/Downloads/zankurd-mac-aktarim.bundle`), GitHub veya herhangi bir genel uzak sunucu değil. Depo hiçbir zaman herkese açık bir yere push edilmemiş. Yani maruziyet şu an **yerel dosya sistemine ve 167 MB'lık bundle dosyasına erişimi olanlarla sınırlı**. Bu, önemi düşürür ama ortadan kaldırmaz. |
| **Düzeltme** | **Sıra önemlidir.** (1) **Önce Hostinger'da şifreyi döndür** — tek gerçek düzeltme budur; geçmişi temizlemek şifre canlı kaldıkça işe yaramaz. (2) FTP yerine yalnız SFTP/anahtar tabanlı erişime geç (HEAD zaten `deploy_sftp.sh`e yöneliyor). (3) Depo herkese açık hâle getirilmeden **önce** geçmişi `git filter-repo` ile temizle ve bundle dosyasını imha et. (4) Yeni sırrı yalnız `.env.deploy` ve GitHub Actions secrets içinde tut (workflow zaten `${{ secrets.HOSTINGER_FTP_* }}` kullanıyor — doğru). |
| **Doğrulama** | Hostinger panelinde şifre değişikliği kaydı; `git log --all -S'<eski-şifre>'` → 0 sonuç (temizlikten sonra); `deploy_sftp.sh` ile başarılı dağıtım |
| **Güven** | **Yüksek** — projenin kendi commit gövdesi ve dosya içeriğiyle doğrulandı |
| **Bağımlılık** | Yok — diğer her şeyden önce yapılmalı |

> **Not.** Bu bulguyu ilk taramamda kaçırdım: geçmiş taramasını dosya *adına*
> göre yapmıştım (`*.env*`, `key.properties`, `*.jks`, `*.p8`), oysa sır bir
> kabuk betiğinin içindeydi. İçerik tabanlı arama (`git log -S`) olmadan
> ad tabanlı tarama yeterli değildir.

### P1 — Yüksek risk / muhtemel red

---

#### `ZKR-REL-20260801-P1-001` — Android release ikilisi üretilemiyor (imzalama varlığı yok)

| Alan | İçerik |
|---|---|
| **Seviye** | P1 |
| **Platform** | Android |
| **Alan** | Build / yayın altyapısı |
| **Durum** | `BLOCKED — ACCOUNT/SIGNING` |
| **Kanıt** | `logs/builds/10_android_aab.log`: *"Release signing configuration is missing or incomplete… Missing or invalid: android/key.properties… will not fall back to debug signing."* Her iki görev de exit 1. |
| **Dosya** | `zankurd_mobile/android/app/build.gradle.kts:24-52` (kapı), `android/key.properties` (yok) |
| **Yeniden üretim** | `cd zankurd_mobile && flutter build appbundle --release` |
| **Beklenen** | İmzalı `app-release.aab` üretilir |
| **Gerçek** | Gradle `GradleException` ile durur, exit 1 |
| **Kullanıcı etkisi** | Yok (kullanıcıya ulaşmıyor) |
| **Store etkisi** | **Play'e yükleme yapılamaz.** Ayrıca boyut, R8 çıktısı, birleştirilmiş release manifesti ve release ikilisinden 16 KB doğrulaması yapılamıyor. |
| **Güvenlik etkisi** | Pozitif — kapı, debug imzalı AAB'nin yayınlanmasını engelliyor |
| **Kök neden** | Bu makinede upload keystore ve `android/key.properties` bulunmuyor (bilinçli olarak repoda tutulmuyor) |
| **Düzeltme** | Sahip, upload keystore'u üretir/geri yükler ve `android/key.properties` dosyasını yerelde oluşturur. **Play App Signing** kullanılıyorsa upload key yeterlidir. Anahtar asla commit edilmemelidir. |
| **Doğrulama** | `flutter build appbundle --release` → exit 0; ardından `bundletool build-apks` + `zipalign -c -P 16` + `llvm-readelf -lW` release `.so`'ları üzerinde |
| **Güven** | Yüksek |
| **Bağımlılık** | P1-004 (16 KB release doğrulaması), P2-003 (native debug symbols) bunu bekliyor |

---

#### `ZKR-REL-20260801-P1-002` — iPad destekleniyor ama iPad düzeni bitmemiş

| Alan | İçerik |
|---|---|
| **Seviye** | P1 |
| **Platform** | iOS / iPadOS |
| **Alan** | Düzen / mağaza kalitesi |
| **Durum** | `VERIFIED FAIL` |
| **Kanıt** | `screenshots/ios/10_ipad_pro13_launch.png` — hero kartı ~1400 pt boş yeşil alan, altında ~400 pt boşluk. `11_ipad_after_skip.png` — başlık içeriği sol %30'a sıkışmış, altta ~600 pt boş alan. Gerçek iPad Pro 13" (M5) simülatörü, iOS 26.5. |
| **Dosya** | `ios/Runner.xcodeproj/project.pbxproj:462` (`TARGETED_DEVICE_FAMILY = "1,2"`); `lib/src/widgets/responsive_wrapper.dart:19` (`maxContentWidth = 1200`), `:22` (`wideThreshold = 600`) |
| **Yeniden üretim** | `flutter build ios --simulator --debug`; `xcrun simctl boot <iPad Pro 13>`; install + launch; ekran görüntüsü al |
| **Beklenen** | iPad'de içerik okunabilir genişlikte toplanır veya tablete uygun düzen kullanılır |
| **Gerçek** | Telefon düzeni 1032 pt genişliğe geriliyor; 1200 pt'lik sınır hiç bağlamıyor |
| **Kullanıcı etkisi** | iPad kullanıcısında bitmemiş/amatör izlenim; büyük boş alanlar |
| **Store etkisi** | Apple, cihaz ailesinde iPad varsa **iPad'de inceler** ve **iPad ekran görüntüsü zorunludur**. Guideline 4.0 (Design) / 2.4.1 kapsamında kalite gerekçeli red riski. |
| **Kök neden** | `ResponsiveWrapper` yalnız masaüstü genişliği düşünülerek yazılmış; sınıfın kendi belgesi *"Gerçek iki sütunlu tablet düzeni… izole bir sprint olarak planlanmalı (M-12)"* diyerek tablet düzeninin ertelendiğini kaydediyor |
| **Düzeltme** | İki seçenekten biri: **(a)** `maxContentWidth`i tablet için ~700-820 pt'e indiren bir breakpoint eklemek (küçük, düşük riskli, iPad'i korur); **(b)** `TARGETED_DEVICE_FAMILY = "1"` yaparak iPhone-only yayınlamak (iPad ekran görüntüsü yükümlülüğünü kaldırır). Ürün kararı sahibindir. |
| **Doğrulama** | iPad Pro 13", iPad mini ve iPad Air simülatörlerinde ana ekranların yeniden görüntülenmesi; `flutter test` regresyonsuz |
| **Güven** | Yüksek |
| **Bağımlılık** | — |

---

#### `ZKR-REL-20260801-P1-003` — Soru kalitesi kapısı başarısız; CI bugün kırmızı

| Alan | İçerik |
|---|---|
| **Seviye** | P1 |
| **Platform** | Her ikisi (CI / yayın süreci) |
| **Alan** | İçerik kalite kapısı / CI |
| **Durum** | `VERIFIED FAIL` |
| **Kanıt** | `dart run tool/question_quality/question_quality_audit.dart gate` → *"Gate source fingerprint changed; baseline metrics were not accepted."* **exit 1**. Parmak izi karşılaştırması: `community_questions.json`, `editorial_questions.json`, `offline_questions.json` → **CHANGED**. |
| **Dosya** | `tool/question_quality/baseline.json` (createdDate `2026-07-15`), `assets/data/*.json`, `.github/workflows/flutter_ci.yml:"Check question quality regressions"` |
| **Yeniden üretim** | Yukarıdaki komut |
| **Beklenen** | Kapı exit 0 verir ve gerçek regresyonlarda kırılır |
| **Gerçek** | Kapı her koşuda exit 1 — **gerçek bir regresyon da aynı hatayla maskelenir** |
| **Kullanıcı etkisi** | Dolaylı: içerik regresyonları yakalanmaz |
| **Store etkisi** | Dolaylı — yayın öncesi "CI yeşil" doğrulaması yapılamaz |
| **Kök neden** | `e6cb01b` (2026-08-01, cevap konumu dengeleme) üç soru dosyasını değiştirdi; `baseline.json` en son `c901521` (2026-07-31) ile güncellenmişti. İçerik düzeltildi, baseline tazelenmedi. |
| **Düzeltme** | Yeni içeriği inceledikten sonra `question_quality_audit.dart baseline` ile parmak izlerini ve metrikleri tazelemek. Yayınlanan bankada blocker/critical **0** olduğu için bu güvenli bir tazelemedir. |
| **Doğrulama** | `dart run tool/question_quality/question_quality_audit.dart gate` → exit 0 |
| **Güven** | Yüksek |
| **Bağımlılık** | P1-004 ile birlikte "CI yeşil" hedefini oluşturur |

---

#### `ZKR-REL-20260801-P1-004` — `dart format` 23 dosyada başarısız; CI biçim adımı kırılıyor

| Alan | İçerik |
|---|---|
| **Seviye** | P1 (yalnız CI'yi kırdığı için; kod etkisi P3) |
| **Platform** | Her ikisi (CI) |
| **Alan** | Kod kalitesi / CI |
| **Durum** | `VERIFIED FAIL` |
| **Kanıt** | `logs/tests/01_analyze_format.log`: *"Formatted 429 files (23 changed)"*. Değişenler arasında `lib/src/data/question_bank_loader.dart`, `lib/src/models/room.dart`, `lib/src/screens/learning_screen.dart`, `lib/src/screens/shop_screen.dart`, `lib/src/services/question_language_policy.dart`, `lib/src/widgets/tournament_bracket_widget.dart` ve 17 test dosyası. |
| **Dosya** | Yukarıdaki 23 dosya; `.github/workflows/flutter_ci.yml` → *"Check formatting"* adımı |
| **Yeniden üretim** | `dart format --output=none --set-exit-if-changed lib test tool tools integration_test` |
| **Beklenen** | Exit 0 |
| **Gerçek** | 23 dosya biçimsiz → CI'nin ilk kapısı düşer, sonraki adımlar (analyze, kalite kapısı, testler, APK) hiç koşmaz |
| **Kullanıcı etkisi** | Yok |
| **Store etkisi** | Dolaylı |
| **Kök neden** | Son içerik/kod turlarında biçimlendirme çalıştırılmamış. Not: CI, `offline_question_bank.dart`ı bilinçli olarak hariç tutuyor — bu 23 dosya o istisnanın dışında. |
| **Düzeltme** | `dart format` çalıştırmak (CI ile aynı hariç tutma listesiyle). |
| **Doğrulama** | Yukarıdaki komut → exit 0; ardından `flutter test` ile regresyon yok |
| **Güven** | Yüksek |
| **Bağımlılık** | — |

---

### P2 — Önemli kalite sorunu

| ID | Başlık | Platform | Durum | Özet ve kanıt |
|---|---|---|---|---|
| `P2-001` | Advertising ID toplanıyor; Data Safety / App Privacy beyanı netleştirilmeli | Her ikisi | `VERIFIED FAIL` (beyan riski) | `aapt2 dump badging` → `com.google.android.gms.permission.AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`, `ACCESS_ADSERVICES_AD_ID`. iOS'ta `GoogleAdsOnDeviceConversion.framework` pakete gömülü. Kaynak: firebase_analytics. **terms.html "reklamsız" diyor** — beyan ile gerçek arasında tutarsızlık riski. Düzeltme: Play Data Safety'de Advertising ID'yi beyan et **veya** `AD_ID` iznini manifestte `tools:node="remove"` ile kaldır ve analytics'i ad-id'siz yapılandır. |
| `P2-002` | Uzak Supabase şeması ile yerel migration'lar arasında doğrulanmamış drift | Backend | `INCONCLUSIVE` | `supabase/applied.md` çok sayıda satırı `?` ("tek tek doğrulanmadı") ile işaretliyor. 105 dosya, 15 `ENABLE ROW LEVEL SECURITY`, 15 `SECURITY DEFINER` ifadesi tarihli dosyalarda. Canlı şema salt okunur karşılaştırması bu turda yapılmadı. |
| `P2-003` | Native debug symbols yapılandırılmamış | Android | `VERIFIED FAIL` | `android/app/build.gradle.kts` içinde `ndk { debugSymbolLevel … }` **yok**. AAB native kod içerdiği için Play Console "debug symbols yüklenmedi" uyarısı verir ve native crash'ler sembolsüz kalır. Düzeltme: `android { buildTypes { release { ndk { debugSymbolLevel = "FULL" } } } }` veya `--split-debug-info` ile sembol yükleme. |
| `P2-004` | Gerçek 16 KB sayfa boyutlu cihazda çalıştırma yapılmadı | Android | `NOT RUN — TOOL MISSING` | Emülatörde `getconf PAGE_SIZE` → **4096**. Kurulu tek imaj `android-36/google_apis/arm64-v8a`. ELF kanıtı güçlü (§3.4) ama çalışma zamanı doğrulaması eksik. Düzeltme: 16 KB sistem imajı kurup release APK ile açılış testi. |
| `P2-005` | Release modda performans ve soğuk açılış ölçülmedi | Her ikisi | `INCONCLUSIVE` | Ölçülen tek sayı debug + SwiftShader emülatöründen: `Displayed … +13s370ms` (veri varken) ve `+3m7s289ms` (veri temizlendikten sonra). Bu rakamlar **release performansını temsil etmez**; JIT + yazılım GPU nedeniyle. Varlıklar küçük (`offline_questions.json` 1.1 MB, `assets/` toplam 8 MB) olduğundan darboğazın veri ayrıştırma olmadığı değerlendirilmiştir. Release ikilisi üretilince gerçek profil alınmalıdır. |
| `P2-006` | `integration_test/` cihazda koşturulmadı | Her ikisi | `NOT RUN` | `integration_test/app_flows_test.dart`, `integration_test/performance_test.dart` mevcut ama bu turda cihazda çalıştırılmadı. CI de bunları koşmuyor. |
| `P2-007` | CI yalnız **debug** APK üretiyor; release yolu hiç denenmiyor | Android | `VERIFIED FAIL` | `.github/workflows/flutter_ci.yml` → *"Build Android APK (debug)"*. Release derleme yolu (R8, ProGuard, imzalama, kaynak küçültme) CI'de hiç sınanmıyor; release-only kırılmalar ancak elde yakalanır. |
| `P2-008` | Firebase'in **yerel otomatik ölçümü** rıza kapısının dışında kalıyor | Her ikisi | `VERIFIED FAIL` | Özel olaylar doğru kapılanmış: `main.dart:207` → `if (analyticsConsentProvider.enabled) { … AnalyticsService.instance.initialize() … }`. **Ancak** `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false` anahtarı ne `ios/Runner/Info.plist`te ne `android/app/src/main/AndroidManifest.xml`te var. Firebase Analytics yerel SDK'sı `Firebase.initializeApp()` ile birlikte varsayılan olarak açıktır ve `first_open` / `session_start` / `app_open` gibi olayları kendiliğinden toplar. `AnalyticsService.disable()` yalnız kullanıcı rızayı **geri çektiğinde** çağrılıyor; rıza hiç verilmemişken çağrılmıyor. Sonuç: varsayılan "kapalı" tercihine rağmen temiz kurulumda yerel otomatik ölçüm başlar. **Düzeltme:** her iki platform manifestine `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false` ekleyip yalnız rıza verildiğinde `setAnalyticsCollectionEnabled(true)` çağırmak. Bu, `ZANKURD_PRIVACY_DATA_MAP.md`deki rıza satırını da nitelendirir. |
| `P2-009` | Paywall boş durumu *"Premium paketler henüz aktif değil"* gösteriyor | Her ikisi | `VERIFIED FAIL` | `lib/src/l10n/strings.dart:1745` → `'tr': 'Premium paketler henüz aktif değil'`; `paywall_screen.dart:17` yorumu bunun bir *"yakında"* görünümü olduğunu söylüyor. RevenueCat teklifleri boş dönerse (dashboard'da ürün tanımlı değilse veya ağ hatasında) inceleme uzmanı bu ekranı görür. Apple 2.1/4.2 kapsamında "tamamlanmamış özellik" gerekçesiyle red riski. `AppConfig.validateForRelease` release'te RevenueCat anahtarı **zorunlu** kıldığı için anahtar eksikliği değil, **dashboard yapılandırması** kritik. **`OWNER CONFIRMATION REQUIRED`:** RevenueCat panelinde `premium` entitlement'ı ve en az bir offering'in canlı olduğu teyit edilmeli. |

### P3 — Polish / temizlik

| ID | Başlık | Kanıt / düzeltme |
|---|---|---|
| `P3-001` | `applied.md` bayat "BEKLİYOR" notu | `2026-08-01_room_question_advance.sql` satırı "BEKLİYOR — canlı çok oyunculu maçları etkiliyor" diyor, oysa istemci RPC'yi çağırıyor (`quiz_screen.dart:1260`) ve test koruyor. Notu güncelle. |
| `P3-002` | Yayınlanan bankada 4 soru 3 şıklı, 1 soru 5 şıklı | Diğer hepsi 2 veya 4 şık. Görsel tutarlılık için normalize edilmeli. Kanıt: `logs/data_quality/34_shipped_bank_metrics.log`. |
| `P3-003` | 15 soruda açıklama yok (%0.8) | `logs/data_quality/35_shipped_bank_metrics_v2.log`. |
| `P3-004` | Gizlilik politikasında iletişim e-postası yok | terms.html ve delete-account.html'de var (`nisebinbawer47@gmail.com`), privacy.html'de yok. Apple 1.2 "published contact information" için tutarlılık iyi olur. |
| `P3-005` | `flutter_tts` Swift Package Manager desteklemiyor | Build uyarısı: *"This will become an error in a future version of Flutter."* Şimdilik zararsız; plugin güncellemesi izlenmeli. |

---

## 9. Regresyonlar

Önceki raporlarda açık bırakılıp bu turda **kapandığı doğrulanan** konular:

- Oda maçında 1. sorudan sonra cevapların kaydedilmemesi → `advance_room_question`
  RPC'si hem migration'da hem istemcide mevcut, testle korunuyor.
- Sohbette kimlik taklidi ve herkese açık `room_messages` okuması → sunucu
  tarafında `sender_id` yeniden yazımı + oda üyeliği politikası.
- Turnuva skorunun sınırsız kabul edilmesi → skor tavanı migration'ı.
- CI'nin depo kökünde olmaması → `.github/workflows/flutter_ci.yml` artık kökte.

**Yeni regresyon:** `baseline.json` tazelenmeden içerik değiştirildiği için soru
kalitesi kapısı kırıldı (P1-003). Bu, 2026-08-01 tarihli içerik commit'iyle
gelen yeni bir durumdur.

---

## 10. Doğrulanamayan alanlar (özet)

| Alan | Etiket |
|---|---|
| Android release AAB/APK, boyut, R8 çıktısı, release manifesti | `BLOCKED — ACCOUNT/SIGNING` |
| Gerçek 16 KB sayfa boyutlu cihazda çalıştırma | `NOT RUN — TOOL MISSING` |
| Kayıt / giriş / şifre sıfırlama / e-posta doğrulama / hesap silme uçtan uca | `BLOCKED — NO SAFE TEST ENVIRONMENT` |
| Satın alma, abonelik, restore akışı | `BLOCKED — ACCOUNT/SIGNING` |
| İki istemcili oda maçı, yeniden bağlanma, host ayrılması | `NOT RUN` |
| Uzak Supabase şeması ↔ migration drift | `INCONCLUSIVE` |
| Release modda performans / cold start / jank / bellek | `NOT RUN` |
| App Store Connect ve Play Console hesap düzeyi kalemler | `BLOCKED — ACCOUNT` (bkz. uyum matrisi) |
| VoiceOver / TalkBack ile uçtan uca okuma | `NOT RUN` |

---

## 11. Öncelikli remediation planı

### Faz 0 — Güvenlik, secret, veri kaybı  ← **ÖNCE BU**
- Bulgular: **`P0-001`** (üretim FTP şifresi git geçmişinde, döndürülmemiş)
- Değişecek dosyalar: **hiçbiri** (ilk adım kodda değil, Hostinger panelinde)
- Adımlar, bu sırayla:
  1. **Hostinger'da FTP/SFTP şifresini döndür.** Tek gerçek düzeltme budur;
     geçmiş temizliği şifre canlı kaldıkça hiçbir işe yaramaz.
  2. Yalnız SFTP/anahtar tabanlı erişime geç (`deploy_sftp.sh` zaten hazır).
  3. Yeni sırrı yalnız `.env.deploy` (gitignore'lu) ve GitHub Actions
     secrets içinde tut.
  4. Depo herkese açık hâle getirilmeden **önce** `git filter-repo` ile
     geçmişi temizle ve `~/Downloads/zankurd-mac-aktarim.bundle` dosyasını imha et.
- Risk: Adım 1 düşük (yalnız kimlik bilgisi değişir, dağıtım betiği güncellenir).
  Adım 4 **yüksek** — geçmiş yeniden yazımı 243 push edilmemiş commit'i etkiler;
  ayrı planlanmalı ve mağaza gönderiminin önkoşulu değildir.
- Bağımlılık: Yok. Diğer bütün fazlardan önce gelir.
- Doğrulama: Hostinger'da şifre değişikliği kaydı; `deploy_sftp.sh` ile başarılı
  dağıtım; (temizlikten sonra) `git log --all -S'<eski-şifre>'` → 0 sonuç
- Geri dönüş: Adım 1-3 için yok (ileriye dönük). Adım 4 öncesi tam yedek alınmalı.
- Büyüklük: **S** (adım 1-3) / **M** (adım 4, ayrı iş)

### Faz 1 — Build ve mağaza blockerları
- Bulgular: `P1-001`
- Değişecek dosyalar: `android/key.properties` (yalnız yerel, commit edilmez)
- Risk: Düşük — kod değişmiyor
- Bağımlılık: Yok
- Doğrulama: `flutter build appbundle --release` → exit 0
- Geri dönüş: Dosyayı silmek yeterli
- Büyüklük: **S**

### Faz 2 — CI'yi yeşile döndürme
- Bulgular: `P1-003`, `P1-004`
- Değişecek dosyalar: 23 kaynak/test dosyası (yalnız biçim), `tool/question_quality/baseline.json`
- Risk: Düşük — biçimlendirme davranışı değiştirmez; baseline tazeleme yayınlanan bankada 0 blocker/0 critical olduğu için güvenli
- Bağımlılık: Yok
- Doğrulama: `dart format … --set-exit-if-changed` → 0; `question_quality_audit.dart gate` → 0; `flutter test` → 1302 geçer
- Geri dönüş: `git checkout` ilgili dosyalar
- Büyüklük: **S**

### Faz 3 — iPad kararı
- Bulgular: `P1-002`
- Değişecek dosyalar: `lib/src/widgets/responsive_wrapper.dart` **veya** `ios/Runner.xcodeproj/project.pbxproj`
- Risk: Orta — düzen değişikliği tüm ekranları etkiler; golden/widget testleri gözden geçirilmeli
- Bağımlılık: Ürün sahibinin (a)/(b) kararı
- Doğrulama: iPad Pro 13" / iPad mini / iPad Air simülatörlerinde ekran turu; `flutter test`
- Geri dönüş: Tek dosyalık değişiklik, kolay geri alınır
- Büyüklük: **M** (a) / **XS** (b)

### Faz 4 — Gizlilik beyanı ve Play/Apple metadata
- Bulgular: `P2-001`, `P3-004`
- Değişecek dosyalar: `android/app/src/main/AndroidManifest.xml` (opsiyonel `AD_ID` kaldırma), web `privacy.html`, Play Console Data Safety formu, App Store Connect App Privacy
- Risk: Düşük
- Büyüklük: **S**

### Faz 5 — Android release sertleştirme
- Bulgular: `P2-003`, `P2-007`, `P2-004`
- Değişecek dosyalar: `android/app/build.gradle.kts`, `.github/workflows/flutter_ci.yml`
- Bağımlılık: Faz 1
- Büyüklük: **M**

### Faz 6 — İçerik cilası
- Bulgular: `P3-002`, `P3-003`, `P3-001`
- Büyüklük: **S**

### Faz 7 — Performans ve dayanıklılık doğrulaması
- Bulgular: `P2-005`, `P2-006`
- Bağımlılık: Faz 1
- Büyüklük: **M**

### Faz 8 — Son release candidate doğrulaması
- Release AAB + imzalı iOS arşivi, gerçek cihazda duman testi, 16 KB cihaz testi,
  iki istemcili oda maçı, mağaza metadata son kontrolü.
- Büyüklük: **L**

### İlk uygulanacak düzeltme paketi (önerilen — 4 bulgu)

> **Faz 0 + Faz 2 + Faz 1**:
> 1. **`P0-001`** — Hostinger şifresini döndür (kod değişikliği yok, en yüksek
>    öncelik, diğer üçünden bağımsız olarak hemen yapılabilir).
> 2. `P1-004` — `dart format` (23 dosya, davranış değişmez).
> 3. `P1-003` — soru kalitesi baseline'ını tazele.
> 4. `P1-001` — keystore'u yerinde oluştur, `flutter build appbundle --release`
>    ile doğrula.
>
> Gerekçe: dördü de dar kapsamlı, birbirinden bağımsız ve düşük riskli.
> 2-4 birlikte "CI yeşil + AAB üretilebilir" durumunu sağlıyor; 1 ise tek
> gerçek güvenlik açığını kapatıyor. `P1-002` (iPad) ürün kararı gerektirdiği,
> geçmiş temizliği (Faz 0 adım 4) ise yüksek riskli olduğu için ikisi de ayrı
> paketlere bırakılmalıdır.
>
> **Ek A'daki adaylar bu pakete dahil edilmemelidir** — önce doğrulanmaları
> gerekir.

---

## 12. Kanıt dizini

```
audit_artifacts/release_audit_2026-08-01/
├── logs/
│   ├── builds/     10_android_aab.log · 11_ios_release.log · 12_android_debug.log
│   │               13_16kb_elf_alignment.log · 14_ios_bundle.log
│   │               15_ios_simulator_build.log · 16_android_manifest_resolved.log
│   │               17_web_release.log · 18_android_assets_proguard.log
│   ├── tests/      01_analyze_format.log · 02_flutter_test_full.log · 03_screen_tour.log
│   ├── data_quality/ 30_question_quality_gate.log · 31_baseline_fingerprint_diff.log
│   │               32_question_quality_report.log · 33_quality_distributions.log
│   │               34_shipped_bank_metrics.log · 35_shipped_bank_metrics_v2.log
│   │               36_broken_correct_answers.log · shipped_bank_audit.py · shipped2.py · broken8.py
│   └── security/   20_secret_tracking.log · 40_supabase_inventory.log
└── screenshots/
    ├── android/      9 gerçek emülatör görüntüsü (Android 16 / API 36)
    ├── ios/          7 gerçek simülatör görüntüsü (iPhone 17 + iPad Pro 13")
    └── tour_render/ 77 test-renderer görüntüsü (tamamlayıcı)
```

Analiz betikleri yalnız `/private/tmp` altında yazılıp kanıt olarak
`logs/data_quality/` içine kopyalanmıştır; uygulama koduna hiçbir betik eklenmemiştir.

---

## Ek A — Paralel analiz aday bulguları (BAĞIMSIZ DOĞRULANMADI)

Bu denetimde, ana incelemeye ek olarak 12 salt-okunur analiz ajanı 12 ayrı
boyutta paralel çalıştırıldı (11 tamamlandı; `supabase-backend` ajanı API
hatasıyla düştü — o boyut §6.2'de elle incelenmiştir). Toplam ~110 aday bulgu
üretildi.

> **Bu bölümün statüsü.** Aşağıdakiler **bulgu değil, doğrulama kuyruğudur.**
> Yalnız bu turda *kendim doğruladıklarım* §8'e bulgu olarak girmiştir
> (P0-001, P2-008, P2-009 buradan yükseltilmiştir). Kalanlar dosya:satır
> kanıtı iddia ediyor ama tek tek teyit edilmedi. **Hiçbiri düzeltme
> gerekçesi olarak, önce doğrulanmadan kullanılmamalıdır.** Denetim kuralı
> gereği (madde 4 ve 10) bunları "geçti/kaldı" olarak işaretlemiyorum.

### A.1 Bu turda yükseltilenler (doğrulandı → §8'e taşındı)

| Aday | Nereye gitti |
|---|---|
| Hostinger FTP şifresi geçmişte açık metin | **P0-001** — doğrulandı, projenin kendi commit notuyla |
| Firebase yerel otomatik ölçümü rıza dışı | **P2-008** — doğrulandı (manifestlerde anahtar yok) |
| Paywall "henüz aktif değil" yer tutucusu | **P2-009** — doğrulandı (`strings.dart:1745`) |
| AD_ID / Data Safety çelişkisi | Zaten **P2-001** olarak bağımsız bulunmuştu |
| Native debug symbols eksik | Zaten **P2-003** |
| CI release varyantı derlemiyor | Zaten **P2-007** |
| iPad cihaz ailesi / düzen | Zaten **P1-002** |

### A.2 Doğrulama kuyruğu — yüksek öncelik

> **2026-08-02 GÜNCELLEME (Aşama 3).** Aşağıdaki adaylardan **yedisi** bağımsız olarak
> doğrulandı. Sonuçlar satır başlarına eklendi; ayrıntılar ve kanıtlar:
> `docs/release_audit/2026-08-02/ZANKURD_PHASE3_RELEASE_CONFIG_AND_HIGH_RISK_VERIFICATION.md`
>
> | Aday | Verdict | Yeni bulgu |
> |---|---|---|
> | A-01 | **VERIFIED DEFECT** | `ZKR-REL-20260802-P1-006` |
> | A-02 | **VERIFIED DEFECT** | `ZKR-REL-20260802-P2-010` |
> | A-03 | **VERIFIED DEFECT** | `ZKR-REL-20260802-P2-011` |
> | A-04 | **NOT A DEFECT** (ölü tablo) | — |
> | A-05 | **VERIFIED DEFECT** | `ZKR-REL-20260802-P1-008` |
> | A-06 | **VERIFIED DEFECT** | `ZKR-REL-20260802-P1-009` |
> | A-10 | **VERIFIED DEFECT** | `ZKR-REL-20260802-P1-007` |
>
> Kalan A-07…A-18 ve §A.3'teki ~85 aday **hâlâ doğrulanmamıştır**.

Bu adaylar doğrulanırsa P0/P1 olabilir. Sonraki turun ilk işi bunlardır.

| # | Boyut | İddia | İddia edilen kanıt |
|---|---|---|---|
| A-01 | Ekonomi | Mağaza 600 coin'lik Neon çerçeveyi satıyor ama sunucunun `spend_coins` beyaz listesi reddediyor → satın alma hiç tamamlanamaz | `shop_screen.dart:141-144` vs `supabase/2026-07-29_release_readiness_hardening.sql`. **Kısmen kontrol ettim:** `avatar_frame_neon` `shop_items` seed'inde var (`2026-07-13_shop_chat_suggestions.sql:51`) ama `shop_screen.dart:47,50` yalnız `avatar_frame_gold` ve `profile_badge_vip` için istemci işleyicisi tanımlıyor — **asimetri gerçek, sonucu doğrulanmalı** |
| A-02 | Erişilebilirlik | Quiz şık kartlarında beyaz metin doğru/yanlış gradyanı üzerinde **2.97:1 ve 3.73:1** — WCAG AA (4.5:1) altında, üstelik en çok görüntülenen ekranda | `quiz_option_tile.dart:114` `textColor`, `AppTheme.correctGradient`/`wrongGradient`. **Not:** `contrast_policy_test.dart` başka yüzeyleri (turuncu, altın bant, heroScrim) ölçüyor; şık gradyanlarını ölçmüyor olabilir |
| A-03 | Gizlilik | Avatar fotoğrafı "kaldırıldığında" Storage nesnesi silinmiyor; tahmin edilebilir genel URL'de kalıcı okunur kalıyor | `avatar_editor_screen.dart` / `supabase_zankurd_repository.dart` |
| A-04 | Gizlilik | Supabase'e yazılan ikinci bir analitik hattı rıza kontrolünden geçmiyor ve gizlilik politikasında açıklanmıyor (`analytics_events` tablosu) | `2026-07-06_persistence.sql:156` `analytics_events` tablosu mevcut |
| A-05 | UGC | Avatar fotoğrafı yabancılara gösterilen **denetimsiz görsel UGC** yüzeyi: süzme/bildirme/engelleme yok | Apple 1.2 kapsamı sohbetle sınırlı değil |
| A-06 | UGC | Görünen adlar üç giriş noktasında da küfür süzgecinden geçmiyor; sunucuda da yok | `profile_name_gate_screen.dart`, `sign_up_screen.dart`, `profile_screen.dart` |
| A-07 | UGC | Bildirilen sohbet mesajı yalnız widget belleğinde gizleniyor; panel kapanınca geri geliyor | `room_chat.dart` |
| A-08 | UGC | Engelleme yalnız sohbette; engellenen oyuncu liderlikte, eşleşmede ve arkadaş isteklerinde görünmeye devam ediyor; `unblock` API'sinin UI çağrısı yok | `supabase_zankurd_repository.dart:685` çağrılmıyor |
| A-09 | UGC | Bildir/engel yalnız **görünür göstergesi olmayan uzun basma** ile erişilebilir | `room_chat.dart` |
| A-10 | Rotalar | `LeaderboardScreen` quiz sonucundan tam rota olarak push ediliyor ama `Scaffold`/`Material` atası ve geri düğmesi yok → iOS'ta çıkışsız ölü uç | `quiz_result_screen.dart`; `AppRoute` `PageRouteBuilder` olduğu için iOS kenar kaydırma da yok |
| A-11 | Özellikler | Yarışma/"Günlük Etkinlik" bir UI kabuğu: skor gönderimi, ödül talebi ve liderlik üretimde no-op | `contest_screen.dart` |
| A-12 | Özellikler | Soru önerisi (UGC) sessizce atılsa bile kullanıcıya başarı bildiriyor | `suggest_question_screen.dart` |
| A-13 | Özellikler | Arkadaş ekle/kabul/reddet, backend çağrısı başarısız olduğunda bile başarı bildiriyor (hata yolu mock'a düşüyor) | `supabase_zankurd_repository.dart` |
| A-14 | İçerik (**canlı sunucu bankası**) | 503 canlı soru (%12; doğru-yanlış kalemlerinin %48.6'sı) cevabı cümle kalıbından belli olan içeriksiz şablonlar | `tool/server_questions_export.csv` |
| A-15 | İçerik (**canlı**) | 628-778 canlı soruda Kurmancî kök + tamamı Türkçe şıklar | aynı |
| A-16 | İçerik (**canlı**) | Canlı bankada hep en uzun şıkkı seçmek **%36.5** doğru veriyor (yerel oran %25±3) | aynı |
| A-17 | İçerik | `wordOrdering` tipinin canlıda hiç içeriği yok; iki asset (54 kayıt) ikilide olmasına rağmen oynanamıyor | `sentence_building_questions.json` |
| A-18 | iOS | Runner hedefinde `DEVELOPMENT_TEAM` yok → temiz checkout'tan arşiv/`build ipa` imzalayamaz | `project.pbxproj` |

> **Önemli kapsam notu.** A-14…A-17 **canlı sunucu bankasına** aittir
> (`tool/server_questions_export.csv`), §5'te ölçtüğüm **paket içi** bankaya
> değil. §5'teki "0 blocker / 0 critical" sonucu paket içi 1832 kayıt için
> geçerlidir ve bu adaylarla çelişmez — iki ayrı veri kümesidir. Uygulama
> çevrimiçi oynarken sunucu bankasını kullandığı için ikisi de önemlidir.

### A.3 Doğrulama kuyruğu — orta ve düşük öncelik (özet)

Kalan ~85 aday şu başlıklarda toplanıyor; ayrıntıları ajan çıktılarındadır
(`audit_artifacts/.../logs/` dışında, oturum transkriptinde):

- **Erişilebilirlik:** dokunma hedefi &lt;44pt/48dp olan yüzeyler; `maxLines`+ellipsis
  ile sessiz kırpma; "hareketi azalt"ın quiz sarsıntısı/çark/sayfa geçişlerinde
  uygulanmaması; Home sekmesinde loading/empty/error/retry olmaması;
  `OfflineBanner`ın yalnız `AppShell` içinde olması; form hatalarının
  duyurulmaması; metin ölçeğinin 2.0x'te sabitlenmesi.
- **Android:** `flutter_tts` için ProGuard keep kuralının artık var olmayan bir
  paketi hedeflemesi; splash logosunun yoğunluk varyantı olmaması; predictive
  back'in opt-in edilmemesi; `localeConfig` olmaması; `QUICKBOOT_POWERON`
  yayınını korumasız kabul eden exported receiver; Amazon IAP bileşenlerinin
  pakete girmesi.
- **iOS:** `UNUserNotificationCenter` delegesinin atanmaması; Crashlytics dSYM
  yükleme fazının olmaması; `AVAudioSession`ın yapılandırılmaması (sessiz
  anahtarına rağmen ses çalma / arka plan sesini kesme); yerelleştirilmiş
  `InfoPlist.strings` olmaması; iPhone yatay yönün açık bırakılması.
- **Ekonomi:** joker coin harcamalarının "ateşle-unut" olması; çark ödülünün
  tamamen takvim tarihinden türemesi; abonelik korumalı değerlerin
  `SharedPreferences`ta sunucu doğrulaması olmadan durması.
- **Gizlilik:** Crashlytics'in koşulsuz açık olması; `ChildSafetyProvider`ın
  ölü kod olması; saklama süresi tanımı ve veri dışa aktarma yolunun olmaması;
  release derlemede analitik olay adlarının cihaz log'una yazılması.
- **Ölü kod / erişilemezlik:** `ErrorDialog`, `BadgeCollectionSection`,
  `ZanaDailyCard` hiçbir yerden çağrılmıyor; bildirimlerin tap handler'ı ve
  payload'ı yok; seviye yerleştirme testi yalnız Ayarlar'dan erişilebiliyor.

### A.4 Sonraki tur için önerilen doğrulama sırası

1. **A-01, A-02, A-10** — kullanıcıyı doğrudan etkileyen, kolay doğrulanır
   (biri para, biri erişilebilirlik eşiği, biri çıkışsız ekran).
2. **A-03, A-04, A-05, A-06** — gizlilik ve UGC; mağaza reddi riski taşır.
3. **A-14…A-17** — canlı sunucu bankası; salt okunur dışa aktarımla ölçülebilir.
4. Kalanlar.
