# ZanKurd — Gizlilik ve Veri Haritası

**Denetim tarihi:** 2026-08-01 · **HEAD:** `5c79000` · **Sürüm:** 1.9.1+13

Bu harita **koddan ve derlenmiş ikiliden** çıkarılmıştır. Koddan kesin olarak
belirlenemeyen alanlar `OWNER CONFIRMATION REQUIRED` ile işaretlenmiştir.

---

## 1. Üçüncü taraf SDK envanteri

`pubspec.yaml` ve derlenmiş `Runner.app` üzerinden doğrulandı.

| SDK | Sürüm | Veri topluyor mu? | Cihazdan çıkan veri | iOS privacy manifest |
|---|---|---|---|---|
| `supabase_flutter` | ^2.14.1 | **Evet** | Hesap, profil, skor, oda/sohbet, öneri | — (Dart/HTTP) |
| `firebase_core` | ^4.12.1 | Dolaylı | — | ✅ pakette |
| `firebase_crashlytics` | ^5.2.6 | **Evet** | Çökme yığını, cihaz/OS bilgisi | ✅ pakette |
| `firebase_analytics` | ^12.4.5 | **Evet** | Olay telemetrisi, **Advertising ID**, cihaz bilgisi, IP | ✅ pakette |
| `purchases_flutter` (RevenueCat) | ^10.6.0 | **Evet** | Satın alma/abonelik durumu, anonim RC kullanıcı kimliği | ✅ pakette |
| `image_picker` | ^1.2.3 | Yerel seçim | Seçilen avatar görseli (yüklenirse) | ✅ pakette |
| `share_plus` | ^13.2.1 | Hayır | — | ✅ pakette |
| `in_app_review` | ^2.0.9 | Hayır | — | ✅ pakette |
| `connectivity_plus` | ^7.3.0 | Hayır | — | ✅ pakette |
| `package_info_plus` | ^10.2.1 | Hayır | — | ✅ pakette |
| `flutter_local_notifications` | ^22.1.0 | Hayır (yerel) | — | ✅ pakette |
| `flutter_timezone` | ^5.1.0 | Hayır | — | ✅ pakette |
| `flutter_tts` | ^4.2.3 | Hayır | Soru metni sistem TTS'ine gider | — |
| `audioplayers` | ^6.1.0 | Hayır | — | — |
| `cached_network_image` | ^3.4.1 | Hayır | Görsel URL istekleri | — |
| `url_launcher` | ^6.3.2 | Hayır | — | ✅ pakette |
| `shared_preferences` | ^2.5.5 | Yerel | — | ✅ pakette |
| **`GoogleAdsOnDeviceConversion.framework`** | (FirebaseAnalytics ile gelir) | **Dolaylı** | Cihaz üstü dönüşüm ilişkilendirmesi | ✅ (Google) |

> **Dikkat:** `GoogleAdsOnDeviceConversion.framework` iOS paketine gömülüdür ve
> Android tarafında `com.google.android.gms.permission.AD_ID`,
> `ACCESS_ADSERVICES_ATTRIBUTION`, `ACCESS_ADSERVICES_AD_ID` izinleri birleştirilmiş
> manifeste girer. Uygulama reklam **göstermese** de bu, mağaza beyanlarında
> "Advertising ID / reklam ilişkilendirmesi" olarak ele alınmalıdır (bulgu P2-001).

---

## 2. İzin ve rıza mimarisi

**Analytics rızası varsayılan olarak KAPALIDIR (opt-in).**
`lib/src/providers/analytics_consent_provider.dart:9` → `AnalyticsConsentProvider({bool initialEnabled = false})`
ve `:22` → `prefs.getBool(_storageKey) ?? false`.
Sınıf belgesi: *"Firebase Analytics yalnızca kullanıcı açıkça izin verdikten sonra
çalışır. Varsayılan kapalıdır; böylece ilk açılışta tercih yapılmadan ölçüm başlamaz."*

**Özel olaylar için bu doğru şekilde uygulanmıştır:** `lib/main.dart:207` →
`if (analyticsConsentProvider.enabled) { … AnalyticsService.instance.initialize() … }`.
Rıza yoksa servis hiç başlatılmaz, dolayısıyla `logEvent` yolundan hiçbir özel
olay gitmez. Tasarım niyeti asgari beklentinin üstündedir.

> ⚠ **Nitelendirme (bulgu P2-008).** Bu kapı **yalnız özel olayları** kapsar.
> `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false` anahtarı ne
> `ios/Runner/Info.plist`te ne `android/app/src/main/AndroidManifest.xml`te
> tanımlı. Firebase Analytics yerel SDK'sı `Firebase.initializeApp()` ile
> birlikte **varsayılan olarak açıktır** ve `first_open`, `session_start`,
> `app_open` gibi olayları kendiliğinden toplar.
> `AnalyticsService.disable()` (`analytics_service.dart:31-40`) yalnız kullanıcı
> rızayı **geri çektiğinde** çağrılıyor — rıza hiç verilmemişken çağrılmıyor.
> Sonuç: temiz kurulumda, tercih "kapalı" olmasına rağmen yerel otomatik ölçüm
> başlayabilir. Aşağıdaki tabloda "yalnız rıza sonrası" ibaresi bu nedenle
> **özel olaylar için** geçerlidir.

`lib/src/providers/child_safety_provider.dart` çocuk güvenliği kapılarını yönetir
(kapsamı hesap düzeyinde hedef kitle kararıyla birlikte teyit edilmelidir).

---

## 3. Veri türü haritası

| Veri | Kaynak | Toplama anı | Zorunlu? | Cihazdan çıkıyor? | Alıcı | Kimliğe bağlı? | Tracking? | Amaç | Silme yolu | Kullanıcı kontrolü |
|---|---|---|---|---|---|---|---|---|---|---|
| E-posta | Kayıt/giriş | Hesap oluşturma | Hayır (misafir mümkün) | Evet | Supabase | Evet | Hayır | Kimlik doğrulama | `delete_my_account` | Hesap silme |
| Kullanıcı adı (görünen ad) | İsim kapısı / profil | İlk açılış (atlanabilir) | Hayır | Evet | Supabase | Evet | Hayır | Liderlik, oda | `delete_my_account` | Düzenleme + silme |
| User ID (UUID) | Supabase Auth | Oturum | Evet | Evet | Supabase | Evet | Hayır | Uygulama işlevi | `delete_my_account` | Hesap silme |
| Oyuncu kodu (`player_tag`) | Sunucu tetikleyicisi | Profil oluşumu | Evet | Evet | Supabase | Evet | Hayır | Arkadaş arama | `delete_my_account` | Hesap silme |
| Profil görseli | `image_picker` (yalnız **galeri**) | Kullanıcı seçerse | Hayır | Evet (yüklenirse) | Supabase Storage | Evet | Hayır | Profil | `delete_my_account` | Kaldırma + silme |
| Quiz/öğrenme geçmişi | Uygulama | Oyun sırasında | — | **Kısmen — XP ve öğrenme ilerlemesi cihaz-yerel** (`applied.md`) | Supabase (skorlar) | Evet | Hayır | İlerleme | `delete_my_account` | Hesap silme |
| Skorlar / liderlik | Uygulama | Oyun sonu | — | Evet | Supabase | Evet | Hayır | Liderlik | `delete_my_account` | Hesap silme |
| Oda / çok oyunculu kayıtlar | Uygulama | Oda oyunu | — | Evet | Supabase | Evet | Hayır | Eşleşme | `delete_my_account` + oda temizleme cron'u | Hesap silme |
| **Oda sohbet mesajları** | Kullanıcı (UGC) | Mesaj gönderme | Hayır | Evet | Supabase | Evet | Hayır | Sosyal | `delete_my_account` | Silme; bildir/engelle |
| **Önerilen sorular** | Kullanıcı (UGC) | Öneri gönderme | Hayır | Evet | Supabase (`suggested_questions`) | Evet | Hayır | İçerik | `delete_my_account` | Silme |
| Arkadaşlık grafiği | Uygulama | Arkadaş ekleme | Hayır | Evet | Supabase | Evet | Hayır | Sosyal | `delete_my_account` | Kaldırma + silme |
| Cihaz bilgisi / OS | Firebase | Rıza sonrası | Hayır | Evet | Google | Evet (analytics) | Hayır | Teşhis | Google saklama politikası | Analytics kapatma |
| IP adresi | Ağ katmanı | Her istek | Evet | Evet | Supabase, Google | Dolaylı | Hayır | Ağ | Sağlayıcı politikası | — |
| Çökme kayıtları | Crashlytics | Çökme anında | Hayır | Evet | Google | Evet | Hayır | Kararlılık | Google saklama politikası | `OWNER CONFIRMATION REQUIRED` — Crashlytics'in de aynı rıza anahtarına bağlı olup olmadığı teyit edilmeli |
| Analytics olayları | Firebase Analytics | **Yalnız rıza sonrası** | Hayır | Evet | Google | Evet | Hayır | Ürün analizi | Google saklama politikası | Ayarlardan kapatma |
| **Advertising ID** | firebase_analytics / AdsOnDeviceConversion | Rıza sonrası | Hayır | Evet | Google | Evet | Beyan gerekli | İlişkilendirme | Google | Analytics kapatma (**teyit gerekli**) |
| Satın alma verisi | RevenueCat + App Store/Play | Satın alma | Hayır | Evet | RevenueCat, Apple/Google | Evet | Hayır | Abonelik | Mağaza politikası | — |
| Push/bildirim token'ı | `profiles.fcm_token` | Bildirim izni sonrası | Hayır | Evet | Supabase | Evet | Hayır | Bildirim | `delete_my_account` | Bildirim kapatma |
| Konum | — | — | — | **Hayır** | — | — | — | — | — | Toplanmıyor |
| Kişiler | — | — | — | **Hayır** | — | — | — | — | — | Toplanmıyor |
| Fotoğraf kitaplığı (kamera) | — | — | — | **Hayır** | — | — | — | — | — | Yalnız galeri seçimi |

---

## 4. Apple App Privacy (nutrition label) taslağı

`ios/Runner/PrivacyInfo.xcprivacy` içindeki **12 beyan edilen tür** (hepsi
`Linked = true`, `Tracking = false`, amaç `AppFunctionality`):

| # | `NSPrivacyCollectedDataType` | Apple kategorisi | Durum |
|---|---|---|---|
| 1 | `UserID` | Identifiers | ✅ kodla uyumlu |
| 2 | `EmailAddress` | Contact Info | ✅ |
| 3 | `Name` | Contact Info | ✅ |
| 4 | `EmailsOrTextMessages` | User Content (sohbet) | ✅ |
| 5 | `OtherUserContent` | User Content (öneriler) | ✅ |
| 6 | `GameplayContent` | User Content | ✅ |
| 7 | `PhotosorVideos` | User Content (avatar) | ✅ |
| 8 | `ProductInteraction` | Usage Data | ✅ |
| 9 | `CrashData` | Diagnostics | ✅ |
| 10 | `PerformanceData` | Diagnostics | ✅ |
| 11 | `DeviceID` | Identifiers | ✅ |
| 12 | `PurchaseHistory` | Purchases | ✅ |

`NSPrivacyTracking = false`, `NSPrivacyTrackingDomains` dizisi mevcut.

**Required-reason API beyanları:**
`NSPrivacyAccessedAPICategoryUserDefaults` → `CA92.1`;
`NSPrivacyAccessedAPICategoryFileTimestamp` → `C617.1`.

Manifest **derlenmiş pakette de doğrulanmıştır** (`Runner.app/PrivacyInfo.xcprivacy`),
yani Apple tarafından okunabilir durumdadır.

`OWNER CONFIRMATION REQUIRED`: ASC formunda "Data Used to Track You" bölümünün
boş bırakılabilmesi, Firebase Analytics'in ad-attribution özelliklerinin
kapalı olduğunun teyidine bağlıdır (bulgu P2-001 / A10).

---

## 5. Google Play Data Safety taslağı

| Veri kategorisi | Toplanıyor | Paylaşılıyor | Zorunlu | Amaç | Şifreli iletim | Silinebilir |
|---|---|---|---|---|---|---|
| Kişisel bilgi → E-posta | Evet | Hayır | Hayır | Hesap yönetimi | Evet (HTTPS) | Evet |
| Kişisel bilgi → Ad | Evet | Hayır | Hayır | Uygulama işlevi | Evet | Evet |
| Kişisel bilgi → User ID | Evet | Hayır | Evet | Uygulama işlevi | Evet | Evet |
| Fotoğraf ve video | Evet (opsiyonel) | Hayır | Hayır | Profil | Evet | Evet |
| Mesajlar → Diğer uygulama içi mesajlar | Evet | Hayır | Hayır | Sosyal | Evet | Evet |
| Uygulama etkinliği → Uygulama içi eylemler | Evet (**rıza ile**) | Evet (Google) | Hayır | Analiz | Evet | Evet |
| Uygulama bilgisi ve performansı → Çökme, tanılama | Evet | Evet (Google) | Hayır | Kararlılık | Evet | Evet |
| Cihaz veya diğer kimlikler → **Advertising ID** | **Evet** | **Evet (Google)** | Hayır | Analiz / ilişkilendirme | Evet | Kısmen | 
| Finansal bilgi → Satın alma geçmişi | Evet | Evet (RevenueCat, mağaza) | Hayır | Abonelik | Evet | Mağaza politikası |
| Konum | **Hayır** | — | — | — | — | — |
| Kişiler | **Hayır** | — | — | — | — | — |

**Veri güvenliği beyanları:**
- Veriler aktarımda şifrelenir: **Evet** (Supabase/Firebase HTTPS).
- Kullanıcı veri silinmesini talep edebilir: **Evet** — uygulama içi
  (`settings_screen.dart:935`) ve `https://www.zankurd.com/delete-account.html`.

`OWNER CONFIRMATION REQUIRED`: Advertising ID satırı — P2-001 kararına göre ya
beyan edilecek ya da izin manifest'ten kaldırılacak.

---

## 6. Hesap silme akışı

| Adım | Uygulama | Kanıt |
|---|---|---|
| Giriş noktası | Ayarlar → Hesap → "Hesabımı Sil" (kırmızı/uyarı stili, ayrı görselleştirme) | `settings_screen.dart:903-984`, `ValueKey('delete-account-action')` |
| 1. onay | Başlık + gövde ile diyalog | `:1099-1123` (`K.deleteConfirmTitle`, `K.deleteConfirmBody`) |
| 2. onay | **Onay kelimesini yazma** zorunluluğu | `:1157-1201` (`ValueKey('delete-confirm-field')`, `K.deleteForever`) |
| Sunucu çağrısı | `client.rpc('delete_my_account')` | `supabase_zankurd_repository.dart:304-311` |
| Sunucu doğrulaması | `applied.md`: canlı fonksiyon ve yalnız `authenticated` çalıştırma yetkisi 2026-07-29'da doğrulandı; katkı/moderasyon yabancı anahtarları güvenle serbest bırakılıyor | `supabase/applied.md` |
| Hata yolu | `ErrorReporter.record` + kullanıcıya SnackBar | `:1221-1226` |
| Web alternatifi | `https://www.zankurd.com/delete-account.html` — `mailto:` talebi, 30 gün | Canlı doğrulandı |

**Durum:** Kod düzeyinde `VERIFIED PASS`. Uçtan uca canlı silme
`BLOCKED — NO SAFE TEST ENVIRONMENT` (gerçek hesap silmek geri alınamaz).

Apple'ın gereksinimi *otomatik oluşturulan ("guest") hesapları da kapsar*
(developer.apple.com/support/offering-account-deletion-in-your-app/, erişim
2026-08-01). ZanKurd misafir oturumu açtığından bu madde geçerlidir ve
karşılanmaktadır.

---

## 7. Yasal bağlantıların canlı doğrulaması

| URL | HTTPS | Yükleniyor | İçerik doğrulandı | Not |
|---|---|---|---|---|
| `https://www.zankurd.com/privacy.html` | ✅ | ✅ | Supabase / Firebase / RevenueCat açıkça sayılıyor; hesap silme yolu tarif ediliyor | **İletişim e-postası yok** (P3-004) |
| `https://www.zankurd.com/terms.html` | ✅ | ✅ | TR + Kurmancî; abonelik ve otomatik yenileme; UGC lisansı; sanal paranın nakde çevrilemezliği | İletişim: `nisebinbawer47@gmail.com` |
| `https://www.zankurd.com/delete-account.html` | ✅ | ✅ | Uygulama içi yol + e-posta talebi; 30 gün taahhüdü | Play "hesap silme URL'si" şartını karşılar |

Uygulama içi erişim: `lib/src/widgets/legal_links.dart` → `AppConfig.privacyPolicyUrl`
(`app_config.dart:95`) ve `termsOfServiceUrl` (`:96`), `LaunchMode.externalApplication`,
dokunma hedefi `minWidth/minHeight: 44` ile garantili. Paywall ve Ayarlar'da gösteriliyor.

**Tespit edilen tutarsızlık:** `terms.html` *"oyun ücretsizdir ve reklam yoktur"*
diyor. Uygulama gerçekten reklam **göstermiyor**, ancak Advertising ID ve reklam
ilişkilendirme çerçeveleri pakete giriyor. Bu, beyan-gerçek çelişkisi riski
oluşturur (P2-001).

---

## 8. Özet karar

| Alan | Durum |
|---|---|
| iOS privacy manifest (uygulama) | `VERIFIED PASS` — mevcut, kapsamlı, pakette |
| Üçüncü taraf SDK privacy manifestleri | `VERIFIED PASS` — 30 adet |
| Required-reason API beyanları | `VERIFIED PASS` |
| Analytics rızası — **özel/custom olaylar** | `VERIFIED PASS` — varsayılan **kapalı** (opt-in); `main.dart:207` rıza kapısı |
| Analytics rızası — **Firebase native auto-collection** | `VERIFIED FAIL` — `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false` her iki manifestte de yok → **P2-008 AÇIK** |
| Crashlytics rıza bağlantısı | `OWNER CONFIRMATION REQUIRED` |
| Advertising ID beyanı | `VERIFIED FAIL` — netleştirilmeli (P2-001) |
| Hesap silme (kod) | `VERIFIED PASS` |
| Hesap silme (uçtan uca) | `BLOCKED — NO SAFE TEST ENVIRONMENT` |
| Gizlilik / koşullar / silme sayfaları | `VERIFIED PASS` — üçü de canlı |
| Apple App Privacy formu | `BLOCKED — ACCOUNT` |
| Play Data Safety formu | `BLOCKED — ACCOUNT` |
