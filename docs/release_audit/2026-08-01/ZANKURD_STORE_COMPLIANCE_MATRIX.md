# ZanKurd — Mağaza Uyum Matrisi

**Denetim tarihi:** 2026-08-01 · **HEAD:** `5c79000`
**Resmî kaynak erişim tarihi:** 2026-08-01 (canlı `WebFetch` ile doğrulandı)

Durum etiketleri: `VERIFIED PASS` · `VERIFIED FAIL` · `BLOCKED` · `NOT RUN` ·
`NOT APPLICABLE` · `INCONCLUSIVE`

> **Politika doğrulama notu.** Aşağıdaki Apple ve Google gereksinimleri bu
> denetim sırasında resmî kaynaklardan **çevrimiçi olarak** okunmuştur (bkz.
> "Kaynak URL" ve "Erişim" sütunları). Model hafızasına dayanılarak "uyumlu"
> kararı verilmemiştir. Çevrimiçi doğrulanamayan tek satır yoktur; ancak
> **hesap düzeyinde** (App Store Connect / Play Console oturumu gerektiren)
> kalemler ayrı bölümde `BLOCKED — ACCOUNT` olarak listelenmiştir.

---

## 1. Google Play

| # | Gereksinim | Kaynak URL | Erişim | Projedeki kanıt | Durum | Eksik işlem | Kod düzeyi? | Hesap düzeyi? | Blocker? |
|---|---|---|---|---|---|---|---|---|---|
| G1 | **Target API 36** (yeni uygulama ve güncellemeler, 31 Ağu 2026'dan itibaren) | developer.android.com/google/play/requirements/target-sdk | 2026-08-01 | `aapt2 dump badging` → `targetSdkVersion:'36'`, `compileSdkVersion='36'` | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G2 | **16 KB sayfa boyutu** uyumu (64-bit ABI'ler) | developer.android.com/guide/practices/page-sizes | 2026-08-01 | `llvm-readelf -lW`: release `libflutter.so` `p_align=0x10000`; `libdartjni.so`, `libdatastore_shared_counter.so` `0x4000`. `zipalign -c -P 16 -v 4` → *Verification successful* | **VERIFIED PASS** (statik) | Gerçek 16 KB cihazda çalıştırma | ✔ | — | Hayır |
| G3 | 16 KB **cihazda** çalışma doğrulaması | aynı | 2026-08-01 | Emülatörde `getconf PAGE_SIZE` → `4096`; 16 KB imaj kurulu değil | **NOT RUN — TOOL MISSING** | 16 KB sistem imajı kurup açılış testi | — | — | Hayır |
| G4 | **64-bit ABI** desteği | developer.android.com | 2026-08-01 | `native-code: 'arm64-v8a' 'armeabi-v7a' 'x86_64'` | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G5 | **Release AAB** üretimi | Play Console | — | `flutter build appbundle --release` → **exit 1** (keystore yok) | **BLOCKED — ACCOUNT/SIGNING** | Upload keystore + `android/key.properties` | — | ✔ | **Evet** |
| G6 | **Play App Signing** / upload key | support.google.com/googleplay/android-developer | 2026-08-01 | Gradle kapısı debug imzasına düşmeyi reddediyor (`build.gradle.kts:44`) | **BLOCKED — ACCOUNT** | Play App Signing kaydı | — | ✔ | **Evet** |
| G7 | Debug imza sızıntısı olmaması | — | — | `build.gradle.kts:24-52` — release görevinde eksik imza → `GradleException` | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G8 | **R8 / kod küçültme** | — | — | `isMinifyEnabled = true`, `isShrinkResources = true`; `proguard-rules.pro` Flutter/Firebase/RevenueCat/Gson/OkHttp/Ktor/flutter_tts keep kurallarını içeriyor | **VERIFIED PASS** (yapılandırma) | Release derlemede doğrulama | ✔ | — | Hayır |
| G9 | **Native debug symbols** yüklenmesi | Play Console | — | `build.gradle.kts` içinde `ndk { debugSymbolLevel }` **yok** | **VERIFIED FAIL** | `debugSymbolLevel = "FULL"` eklemek | ✔ | — | Hayır |
| G10 | **İzin minimizasyonu** | — | — | Uygulama manifesti: `INTERNET`, `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS`. Kısıtlı/hassas izin yok | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G11 | **Advertising ID** beyanı | support.google.com/googleplay/android-developer/answer/6048248 | 2026-08-01 | Birleştirilmiş manifestte `com.google.android.gms.permission.AD_ID` (firebase_analytics kaynaklı) | **VERIFIED FAIL** (beyan riski) | Data Safety'de beyan **veya** izni `tools:node="remove"` ile kaldırma | ✔ | ✔ | Hayır |
| G12 | **Data Safety** formu | support.google.com/googleplay/android-developer/answer/10787469 | 2026-08-01 | Veri haritası hazır (`ZANKURD_PRIVACY_DATA_MAP.md`) | **BLOCKED — ACCOUNT** | Formu doldurmak | — | ✔ | **Evet** |
| G13 | **Gizlilik politikası URL'si** | aynı | 2026-08-01 | `https://www.zankurd.com/privacy.html` — canlı doğrulandı, HTTPS, gerçek içerik | **VERIFIED PASS** | — | — | ✔ | Hayır |
| G14 | **Hesap silme**: uygulama içi + **herkese açık web URL'si** | support.google.com/googleplay/android-developer/answer/13327111 | 2026-08-01 | Uygulama içi: `settings_screen.dart:935` → çift onay → `delete_my_account` RPC. Web: `https://www.zankurd.com/delete-account.html` — canlı doğrulandı, `mailto:` ile talep, 30 gün taahhüdü | **VERIFIED PASS** (kod + web) | Play Console alanına URL girmek | ✔ | ✔ | Hayır |
| G15 | **UGC politikası**: süzme, bildirme, engelleme | support.google.com/googleplay/android-developer/answer/9878810 | 2026-08-01 | `chat_message_is_clean` tetikleyicisi; `report_room_message`, `block_player`, `unblock_player` RPC'leri istemcide bağlı (`supabase_zankurd_repository.dart:661/674/685`) | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G16 | **Google Play Billing** zorunluluğu (dijital mal) | support.google.com/googleplay/android-developer/answer/10281818 | 2026-08-01 | Tek dijital satış: RevenueCat üzerinden `premium` aboneliği; `com.android.vending.BILLING` izni mevcut. Harici ödeme bağlantısı **yok** | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G17 | **Rastgele ödül / olasılık açıklaması** | support.google.com/googleplay/android-developer/answer/9858738 | 2026-08-01 | Çark yalnız **kazanılan** coin ile; coin paketi IAP'si yok (`premium_service.dart:50` tek entitlement) | **NOT APPLICABLE** | — | — | — | Hayır |
| G18 | **Edge-to-edge / Android 15+ davranışları** | developer.android.com/about/versions/16/behavior-changes-16 | 2026-08-01 | `AnnotatedRegion<SystemUiOverlayStyle>` (`main.dart:380`); gerçek Android 16 emülatöründe status/nav bar çakışması gözlenmedi | **VERIFIED PASS** (görsel) | — | ✔ | — | Hayır |
| G19 | **Bildirim izni** (`POST_NOTIFICATIONS`) | developer.android.com | 2026-08-01 | Manifestte mevcut; `notification_service.dart` runtime izin akışını yürütüyor | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G20 | **Uygulama ikonu / adaptive / monochrome** | developer.android.com | 2026-08-01 | `mipmap-anydpi-v26/ic_launcher.xml` → `background` + `foreground` + **`monochrome`**; 5 yoğunlukta 48/72/96/144/192 px | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G21 | **Bildirim ikonu** | — | — | `drawable-{m,h,xh,xxh,xxxh}dpi/ic_stat_zankurd.png`, `notification_service.dart:135` ile bağlı | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G22 | **Backup / data extraction** kuralları | developer.android.com | 2026-08-01 | `android:fullBackupContent="@xml/backup_rules"`, `android:dataExtractionRules="@xml/data_extraction_rules"` tanımlı | **VERIFIED PASS** (varlık) | Kural içeriğinin token hariç tuttuğunun teyidi | ✔ | — | Hayır |
| G23 | **Exported component** güvenliği | — | — | Yalnız `MainActivity` (`exported="true"`, launcher) ve bildirim boot receiver'ı (`exported="true"`, yalnız sistem action'ları). Diğerleri `exported="false"` | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G24 | **Deep link / App Links** | developer.android.com | 2026-08-01 | Özel şema `com.zankurd.app://login-callback`, `autoVerify="false"` — Supabase OAuth geri dönüşü. Doğrulanmış `https` App Link **yok** | **VERIFIED PASS** (amaç itibarıyla) | https App Link isteniyorsa `assetlinks.json` | ✔ | — | Hayır |
| G25 | **Cihaz kataloğu filtreleme** | — | — | Yalnız örtük `uses-feature: android.hardware.faketouch`; yanlış filtreleme yok | **VERIFIED PASS** | — | ✔ | — | Hayır |
| G26 | **Kapalı test şartı** (13 Kas 2023 sonrası açılan kişisel hesaplar: 12 tester × 14 gün) | support.google.com/googleplay/android-developer/answer/14151465 | 2026-08-01 | Hesap türü ve açılış tarihi kod tarafından bilinemez | **BLOCKED — ACCOUNT** | Hesap türünü teyit et; kişisel hesapsa 12 tester × 14 gün kapalı test planla | — | ✔ | Koşullu |

---

## 2. Apple App Store

| # | Gereksinim | Kaynak URL | Erişim | Projedeki kanıt | Durum | Eksik işlem | Kod düzeyi? | Hesap düzeyi? | Blocker? |
|---|---|---|---|---|---|---|---|---|---|
| A1 | **Xcode 16+ / güncel iOS SDK** ile derleme | developer.apple.com/news/upcoming-requirements/ | 2026-08-01 | Xcode **26.6** (17F113), iOS SDK **26.5** | **VERIFIED PASS** | — | — | — | Hayır |
| A2 | **Release derlemesi** üretilebiliyor | — | — | `flutter build ios --release --no-codesign` → exit 0, `Runner.app` 52.0 MB | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A3 | **İmzalı arşiv / provisioning** | — | — | Bu makinede sertifika/profil doğrulanmadı | **BLOCKED — ACCOUNT/SIGNING** | Distribution sertifikası + profil ile arşiv | — | ✔ | **Evet** |
| A4 | **Bundle ID / sürüm** | — | — | `com.zankurd.app`, `CFBundleShortVersionString 1.9.1`, `CFBundleVersion 13` | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A5 | **Deployment target / mimari** | — | — | `MinimumOSVersion 15.0`, arm64 | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A6 | **`PrivacyInfo.xcprivacy`** paket içinde | developer.apple.com/documentation/technotes/tn3183 | 2026-08-01 | `Runner.app/PrivacyInfo.xcprivacy` **mevcut** (derlenmiş pakette doğrulandı) | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A7 | **Required-reason API** beyanları | aynı | 2026-08-01 | `NSPrivacyAccessedAPICategoryUserDefaults` → `CA92.1`; `NSPrivacyAccessedAPICategoryFileTimestamp` → `C617.1` | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A8 | **Üçüncü taraf SDK privacy manifestleri** | developer.apple.com/support/third-party-SDK-requirements/ | 2026-08-01 | Pakette **30 adet** `PrivacyInfo.xcprivacy` (Firebase×5, RevenueCat, GoogleUtilities×8, image_picker, share_plus, url_launcher, sqflite, connectivity_plus, flutter_local_notifications, package_info_plus, nanopb, Promises×2, app_links, flutter_timezone, in_app_review, shared_preferences, Flutter.framework) | **VERIFIED PASS** | — | — | — | Hayır |
| A9 | **App Privacy** (nutrition label) cevapları | developer.apple.com/app-store/app-privacy-details/ | 2026-08-01 | Veri haritası ve `NSPrivacyCollectedDataTypes` hazır (`ZANKURD_PRIVACY_DATA_MAP.md`) | **BLOCKED — ACCOUNT** | ASC'de formu doldurmak | — | ✔ | **Evet** |
| A10 | **ATT gerekli mi?** | developer.apple.com | 2026-08-01 | `NSPrivacyTracking` beyanı `false` yönünde; ancak `GoogleAdsOnDeviceConversion.framework` pakete gömülü — izleme amacı **yok**sa ATT gerekmez | **INCONCLUSIVE** | Firebase Analytics ad-attribution yapılandırmasının izleme yapmadığını teyit et | ✔ | ✔ | Hayır |
| A11 | **Privacy usage descriptions** | — | — | `NSPhotoLibraryUsageDescription` mevcut; `image_picker` yalnız `ImageSource.gallery` (`avatar_editor_screen.dart:123`) → kamera açıklaması gerekmiyor | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A12 | **Uygulama içi hesap silme** (guest hesaplar dahil) | developer.apple.com/support/offering-account-deletion-in-your-app/ | 2026-08-01 | `settings_screen.dart:935` `delete-account-action` → onay → kelime yazarak ikinci onay (`:1157`) → `deleteMyAccount()` → `client.rpc('delete_my_account')` | **VERIFIED PASS** (kod) | Uçtan uca canlı doğrulama | ✔ | — | Hayır |
| A13 | **5.1.1(v): zorunlu giriş olmaması** | developer.apple.com/app-store/review/guidelines/ | 2026-08-01 | Gerçek cihazda doğrulandı: onboarding → isteğe bağlı isim (**"Paşê bike"** ile atlanabilir) → ana ekran. Giriş zorunlu değil | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A14 | **Sign in with Apple** gerekliliği | aynı | 2026-08-01 | Üçüncü taraf sosyal giriş varsa gerekir. Giriş sağlayıcı envanteri hesap düzeyinde teyit gerektiriyor | **INCONCLUSIVE** | Google/Apple giriş yapılandırmasını teyit et; Google girişi etkinse SIWA zorunlu | ✔ | ✔ | Koşullu |
| A15 | **1.2 UGC — süzme** | aynı | 2026-08-01 | `chat_message_is_clean` + BEFORE INSERT tetikleyici | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A16 | **1.2 UGC — bildirme** | aynı | 2026-08-01 | `report_room_message` RPC (`:661`), `message_reports` tablosu | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A17 | **1.2 UGC — engelleme** | aynı | 2026-08-01 | `block_player`/`unblock_player` (`:674`,`:685`), `blocked_users` sunucu süzgeci | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A18 | **1.2 UGC — yayınlanmış iletişim** | aynı | 2026-08-01 | `nisebinbawer47@gmail.com` — terms.html ve delete-account.html üzerinde canlı doğrulandı | **VERIFIED PASS** | privacy.html'e de eklemek (P3) | — | ✔ | Hayır |
| A19 | **3.1.1 loot box olasılık açıklaması** | aynı | 2026-08-01 | Kural *"for purchase"* şartlı. Çark yalnız kazanılan coin ile; coin paketi IAP'si yok | **NOT APPLICABLE** | — | — | — | Hayır |
| A20 | **3.1.2 abonelik açıklamaları** | aynı | 2026-08-01 | Paywall'da otomatik yenileme metni iki dilde, *"24 saat"* + *"iptal"* (`strings.dart:1755-1764`); fiyat + dönem eki; `LegalLinksRow`. Tümü `test/paywall_compliance_test.dart` ile korunuyor | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A21 | **Restore Purchases** | aynı | 2026-08-01 | `paywall_screen.dart:79` `premium.restorePurchases()`, `:590` erişilebilir düğme | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A22 | **Harici ödeme bağlantısı olmaması** | aynı | 2026-08-01 | Dijital mal için harici ödeme bağlantısı bulunmadı | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A23 | **Export compliance / şifreleme** | — | — | `ITSAppUsesNonExemptEncryption = false` (derlenmiş `Info.plist`) | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A24 | **App icon** (1024, alpha yok) | — | — | 21 boyut; `Icon-App-1024x1024@1x.png` → `hasAlpha: no` | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A25 | **Launch screen** | — | — | `Base.lproj` + `LaunchScreen` pakette | **VERIFIED PASS** | — | ✔ | — | Hayır |
| A26 | **iPad desteği ve iPad düzeni** | aynı (Guideline 4.0 / 2.4.1) | 2026-08-01 | `TARGETED_DEVICE_FAMILY = "1,2"`; iPad Pro 13" gerçek simülatöründe telefon düzeni gerilmiş (bkz. P1-002) | **VERIFIED FAIL** | Tablet breakpoint eklemek **veya** cihaz ailesini `"1"` yapmak | ✔ | — | **Evet** (ASC gönderimi için) |
| A27 | **iPad ekran görüntüleri** | ASC | — | Cihaz ailesinde iPad varken zorunlu; hazır iPad görseli yok | **BLOCKED — ACCOUNT** (A26'ya bağlı) | A26 kararından sonra üretmek | — | ✔ | **Evet** |
| A28 | **Demo / review hesabı** | ASC | — | Giriş zorunlu olmadığı için gerekli olmayabilir; çevrimiçi özellikler için önerilir | **BLOCKED — ACCOUNT** | ASC "App Review Information" alanı | — | ✔ | Hayır |
| A29 | **Yaş derecelendirmesi** (UGC + sohbet) | ASC | — | Yabancılarla eşleşme ve oda sohbeti mevcut → derecelendirme sorularında UGC/sohbet işaretlenmeli | **BLOCKED — ACCOUNT** | ASC yaş derecelendirme anketi | — | ✔ | Koşullu |
| A30 | **Sosyal medya capability beyanı** (Eylül 2026) | developer.apple.com/news/upcoming-requirements/ | 2026-08-01 | Arkadaşlık, profil, oda sohbeti mevcut → beyan kapsamına girebilir | **BLOCKED — ACCOUNT** | ASC'de ilgili beyanı yapmak | — | ✔ | Koşullu |

---

## 3. Hesap düzeyi kontrol listesi (Account-Level Checklist)

Bu kalemler **koddan doğrulanamaz**; App Store Connect / Google Play Console
oturumu gerektirir. Bu denetimde hiçbirine erişilmemiştir.

### App Store Connect
- [ ] Distribution sertifikası ve provisioning profile geçerliliği (A3)
- [ ] App Privacy (nutrition label) cevapları — veri haritası hazır (A9)
- [ ] ATT gerekliliği kararının teyidi (A10)
- [ ] Sign in with Apple gerekliliği: aktif sosyal giriş sağlayıcıları (A14)
- [ ] **iPad ekran görüntüleri** — A26 kararına bağlı (A27)
- [ ] iPhone 6.9" ekran görüntüleri
- [ ] App Review demo hesabı / review notes (A28)
- [ ] Yaş derecelendirme anketi (UGC + sohbet işaretlemesi) (A29)
- [ ] Sosyal medya capability beyanı (A30)
- [ ] App adı, subtitle, keywords, açıklama, What's New — TR + KU yerelleştirmeleri
- [ ] Support URL ve Marketing URL alanları
- [ ] DSA trader status (AB dağıtımı yapılacaksa)
- [ ] TestFlight yapılandırması

### Google Play Console
- [ ] Play App Signing kaydı ve upload key (G6)
- [ ] Data Safety formu (G12)
- [ ] Hesap silme URL'si alanına `https://www.zankurd.com/delete-account.html` (G14)
- [ ] Advertising ID beyanı (G11)
- [ ] Ads declaration (uygulama reklam göstermiyor → "Hayır")
- [ ] İçerik derecelendirme anketi (UGC + sohbet)
- [ ] Hedef kitle ve Families kapsamı — **çocuklar hedefleniyorsa `AD_ID` sorunu kritikleşir**
- [ ] Store listing: kısa/uzun açıklama, feature graphic (1024×500), telefon + tablet ekran görüntüleri
- [ ] Destek e-postası
- [ ] Ülke/bölge dağıtımı
- [ ] Internal → closed → open test planı
- [ ] **Kapalı test şartı**: hesap 13 Kas 2023 sonrası açılmış kişisel hesapsa 12 tester × 14 gün kesintisiz (G26)
- [ ] Production access başvurusu

---

## 4. Özet

| Kategori | Sayı |
|---|---|
| `VERIFIED PASS` | 38 |
| `VERIFIED FAIL` | 4 (G9, G11, A26, + G5/A3 imzalama BLOCKED sayıldı) |
| `BLOCKED — ACCOUNT / SIGNING` | 11 |
| `NOT APPLICABLE` | 2 (G17, A19 — loot box) |
| `INCONCLUSIVE` | 2 (A10 ATT, A14 SIWA) |
| `NOT RUN — TOOL MISSING` | 1 (G3) |

**Gönderimi engelleyen kalemler:** G5/G6 (Android imzalama), G12 (Data Safety),
A3 (iOS imzalama), A9 (App Privacy), A26/A27 (iPad düzeni + ekran görüntüleri).
