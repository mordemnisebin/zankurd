# Android İmzalama (Release Signing) Kurulumu

Play Store'a yüklenecek AAB'nin bir **upload key** ile imzalanması gerekir.
`android/app/build.gradle.kts` bu yapılandırmayı `android/key.properties`
dosyasından okur; dosya yoksa veya eksikse release derlemesi **güvenlik için
durur** (debug imzasına düşmez).

> ⚠️ `key.properties` ve `.jks`/`.keystore` dosyaları **asla commit edilmez**
> (`.gitignore`'da). Keystore'u kaybedersen Play Store'da uygulamayı
> güncelleyemezsin — proje dışında yedekle.

## Derlemenin geri kalanı doğrulandı (2026-07-27)

Senin keystore'un dışında release yolunda eksik bir şey kalmadı. Geçici
bir anahtarla `flutter build appbundle --release` sonuna kadar koştu:

- AAB üretildi (72,5 MB). Bunun ~70 MB'ı `BUNDLE-METADATA` altındaki hata
  ayıklama sembolleri ve ProGuard eşlemesi; Play bunları cihaza
  göndermez, yalnız çökme çözümlemesi için saklar. Cihaza inen paket çok
  daha küçüktür.
- R8 küçültme ve kaynak temizleme açık ve **eksik sınıf uyarısı
  üretmedi** (`missing_rules.txt` hiç oluşmadı). Release'e özgü
  çökmelerin en yaygın sebebi budur; `proguard-rules.pro` eklentileri
  kapsıyor demektir.
- Yazı tipleri ağaç budamasıyla küçüldü (ikon fontlarında %89-99).

Geçici anahtar ve `key.properties` doğrulamadan sonra silindi; depoda iz
kalmadı. Aşağıdaki adımlar hâlâ senin yapman gereken kısım.

## 1. Upload keystore oluştur (bir kez)

JDK 17 bu makinede kurulu (`/opt/homebrew/opt/openjdk@17`). Terminalde:

```bash
keytool -genkeypair -v \
  -keystore ~/zankurd-upload.jks \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

- Bir **keystore parolası** ve **key parolası** sorulacak — güçlü seç, güvenli
  bir yerde sakla (parola yöneticisi).
- İsim/kurum sorularını doldur (Play için kritik değil).
- Dosyayı proje dışında tut (ör. `~/zankurd-upload.jks`) ve yedekle.

## 2. `android/key.properties` oluştur

`zankurd_mobile/android/key.properties` (gitignore'lu) dosyasını şu içerikle
oluştur — parolaları kendi değerlerinle değiştir:

```properties
storeFile=/Users/<kullanıcı>/zankurd-upload.jks
storePassword=<keystore-parolası>
keyAlias=upload
keyPassword=<key-parolası>
```

`storeFile` mutlak yol olmalı ve var olan `.jks`'yi göstermeli.

## 3. Release AAB derle

> ⚠️ Daha önce bir **debug** build aldıysan, release'ten önce `flutter clean`
> çalıştır. Aksi halde debug'dan kalma `GeneratedPluginRegistrant.java`,
> release'te bulunmayan `integration_test` (dev-dependency) paketini arar ve
> derleme "package dev.flutter.plugins.integration_test does not exist" hatası
> verir. `flutter clean` registrant'ı release için doğru yeniden üretir.

```bash
flutter clean
flutter build appbundle --release \
  --dart-define=REVENUECAT_API_KEY_ANDROID=<play-public-key> \
  --dart-define=REVENUECAT_API_KEY_IOS=<app-store-public-key>
```

- RevenueCat anahtarları verilmezse premium **mock modda** kalır (satın alma
  devre dışı; uygulama çalışır). Canlı abonelik için anahtarlar zorunlu.
- Çıktı: `build/app/outputs/bundle/release/app-release.aab` → Play Console'a
  yükle.

## 4. Doğrulama (yapıldı)

- `key.properties` + geçici test keystore ile `flutter build appbundle
  --release` bu makinede başarıyla derlendi; **R8/minify** (kod küçültme,
  `android/app/proguard-rules.pro`) release'i bozmuyor.
- Play App Signing açıksa yalnız **upload key** senin sorumluluğunda; Google
  dağıtım anahtarını yönetir.

## İlgili

- Kod küçültme kuralları: `android/app/proguard-rules.pro`
- Play gönderim kontrol listesi: `docs/play_console_submission_checklist.md`
- iOS/masaüstü gereksinimleri: `docs/multi_platform_release.md`
- Gizlilik/koşullar URL'leri: `AppConfig.privacyPolicyUrl` /
  `AppConfig.termsOfServiceUrl` (uygulama içi linkler bunlara bağlı; sayfalar
  yayında olmalı).
