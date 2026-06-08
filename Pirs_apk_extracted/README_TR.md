# Pirs APK çıkarım özeti

Bu rapor, yüklenen APK dosyasının statik olarak çıkarılmış/çözümlenmiş özetidir. Amaç, uygulamayı birebir kopyalamak değil; benzer bir quiz uygulamasını sıfırdan geliştirmek için mimari ve içerik haritası çıkarmaktır.

## APK metadata
- Dosya: `Pirs - Kurdish Online Quiz_15_APKPure.apk`
- Boyut: 19,227,590 bayt
- SHA-256: `aabeefaec98d1e9238bbdbc621e8edb21e5c98ac2575f65fdcfaf3737d3e9602`
- Paket adı: `kurdi.leyzok.pirs`
- Sürüm: versionName `15`, versionCode `23`
- SDK: min `21`, target `31`, compile `31`
- Ana Application sınıfı: `kurdi.leyzok.pirs.helper.AppController`
- Launcher Activity: `kurdi.leyzok.pirs.activity.SplashActivity`

## Ana izinler
- `android.permission.VIBRATE`
- `android.permission.ACCESS_NETWORK_STATE`
- `android.permission.ACCESS_WIFI_STATE`
- `android.permission.INTERNET`
- `android.permission.CAMERA`
- `com.android.vending.BILLING`
- `android.permission.READ_EXTERNAL_STORAGE`
- `android.permission.WRITE_EXTERNAL_STORAGE`
- `android.permission.READ_PHONE_STATE`
- `android.permission.WRITE_SETTINGS`
- `android.permission.WAKE_LOCK`
- `com.google.android.c2dm.permission.RECEIVE`
- `android.permission.FOREGROUND_SERVICE`
- `com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE`
- `com.google.android.gms.permission.AD_ID`
- `android.permission.RECEIVE_BOOT_COMPLETED`

## Ana ekranlar / modüller
Uygulamanın kendi paketindeki Activity sayısı: 45. Öne çıkan akışlar:
- Giriş ve profil: `LoginTabActivity`, `ProfileActivity`
- Ana quiz akışı: `MainActivity`, `CategoryActivity`, `SubcategoryActivity`, `LevelActivity`, `PlayActivity`, `CompleteActivity`, `ReviewActivity`
- Matematik/öğrenme: `MathSubcategoryActivity`, `MathsPlayActivity`, `MathsReviewActivity`, `LearningZoneActivity`, `LearningChapterActivity`
- Bookmark: `BookmarkList`, `BookmarkPlay`
- Rekabet: `LeaderboardTabActivity`, `ContestActivity`, `TournamentPlay`, `BattlePlayActivity`, `RobotPlayActivity`, `one_to_one.*`, `battle.*`
- Gelir/ödül: `CoinStoreActivity`, `RewardActivity`, spin wheel: `spin.SpinActivity`
- Bildirim/ayar: `NotificationList`, `SettingActivity`, `InstructionActivity`, `PrivacyPolicy`

## Servisler ve entegrasyonlar
- Firebase Messaging: `kurdi.leyzok.pirs.service.MyFirebaseMessagingService`
- Firebase Auth / Realtime Database / Storage / Analytics bileşenleri mevcut.
- Google Ads / AdMob ve Facebook Audience Network bileşenleri mevcut.
- Google Play Billing Client version `4.0.0` metadata içinde görünüyor.
- Facebook Login/CustomTab bileşenleri mevcut.
- CanHub image cropper kullanılmış.
- Room/SQLite, WorkManager ve AndroidX destek kütüphaneleri mevcut.

## Asset ve yerel veri
- `assets/quiz_bookmark.db`: bookmark için boş SQLite şablonu. Tablo: `tbl_bookmark`.
- `assets/quiz_level.db`: level ilerlemesi için boş SQLite şablonu. Tablo: `level`.
- `assets/settingani.json`: Lottie ayar animasyonu.
- `assets/MathJax/`: matematik gösterimi için MathJax paketi.
- `assets/audience_network.dex`: Facebook Audience Network ek DEX dosyası.

## Çıkarılan okunabilir dosyalar
- `AndroidManifest.decoded.xml`: okunabilir manifest.
- `decoded_xml/`: APK içindeki binary XML kaynaklarının okunabilir XML çıktıları.
- `raw_apk_contents/`: APK içeriğinin ham klasör yapısı.
- `databases/`: SQLite şema ve CSV dökümleri.
- `dex_info/`: DEX başlık bilgileri, sınıf listeleri ve uygulama sınıf listeleri.
- `reports/`: envanter, kaynak özeti, URL/endpoint listesi ve kırpılmış string raporları.

## Benzer uygulama için önerilen sıfırdan geliştirme mimarisi
- Android/Kotlin + MVVM + Room + Retrofit/Firebase modülleri.
- Özellikler: kategori/listeleme, seviye sistemi, soru ekranı, seçenek kontrolü, puan/coin/ödül, bookmark, leaderboard, contest/tournament, bildirim, profil, ayarlar, reklam ve satın alma modülleri.
- Veritabanı: `Question`, `Category`, `SubCategory`, `LevelProgress`, `Bookmark`, `UserProfile`, `Match`, `Tournament`, `Notification` tabloları.
- Backend: Firebase Auth, Firestore veya Realtime Database, Cloud Storage ve FCM kullanılabilir; mevcut APK’daki API anahtarları/proje bilgileri yeniden kullanılmamalıdır.

## Not
Bu paket, APK’nin statik analizidir. DEX bayt kodu Java/Kotlin kaynak koduna tam olarak dönüştürülmedi; araç ortamında `jadx`/`apktool` yoktu. Yine de manifest, kaynaklar, asset’ler, veritabanları ve sınıf/endpoint envanteri Codex’e bağlam vermek için hazırlandı.
