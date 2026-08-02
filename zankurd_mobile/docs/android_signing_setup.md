# Android İmzalama (Release Signing) Doğrulaması

Play Store'a yüklenecek AAB'nin bir **upload key** ile imzalanması gerekir.
`android/app/build.gradle.kts` bu yapılandırmayı `android/key.properties`
dosyasından okur; dosya yoksa veya eksikse release derlemesi **güvenlik için
durur** (debug imzasına düşmez).

> ⚠️ `key.properties` ve `.jks`/`.keystore` dosyaları **asla commit edilmez**
> (`.gitignore`'da). Keystore'u kaybedersen Play Store'da uygulamayı
> güncelleyemezsin. Var olan anahtarı yeniden üretme veya değiştirme.

## Doğrulanmış yerel durum (2026-08-02)

- Upload keystore:
  `/Users/kocer/.zankurd/signing/zankurd-upload.jks`
- Alias: `zankurd-upload`
- `android/key.properties` bu yolu ve alias değerini kullanıyor.
- Parolalar macOS Keychain'de; belgeye veya komut satırına yazılmıyor.
- Doğrulanmış imzalı AAB çalışma çıktıları temizlenirken silindi. Keystore ve
  yerel `.env.mobile.release.json` durduğu için aynı paket yeniden üretilebilir.

Release yolu R8 küçültme, kaynak temizleme ve native debug sembolleriyle
yapılandırılmıştır. Release imzası eksik veya hatalıysa derleme güvenlik için
durur; debug imzasına düşmez.

## 1. Anahtar yolunu ve sertifikayı doğrula

Parolaları terminale yazdırmadan önce dosyayı, ardından yalnız yol ile alias
alanlarını denetle:

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
test -f /Users/kocer/.zankurd/signing/zankurd-upload.jks
awk -F= '$1 == "storeFile" || $1 == "keyAlias" { print }' android/key.properties
```

Beklenen çıktı:

```text
storeFile=/Users/kocer/.zankurd/signing/zankurd-upload.jks
keyAlias=zankurd-upload
```

Keychain'deki parola istendiğinde girerek sertifikayı incele:

```bash
keytool -list -v \
  -keystore /Users/kocer/.zankurd/signing/zankurd-upload.jks \
  -alias zankurd-upload
```

Çıktıdaki sertifika SHA-256 parmak izi şu doğrulanmış değerle **birebir** aynı
olmalı:

```text
80:59:2E:73:81:FE:05:2B:0C:E1:49:F2:09:06:0F:32:CC:7B:53:F3:5B:92:E2:FC:39:58:DD:19:32:E8:98:B3
```

Play Console upload sertifikası kaydı oluştuğunda oradaki SHA-256 da aynı
olmalıdır. Dosya yoksa, alias/parmak izi farklıysa veya sertifika açılamıyorsa
yeni anahtar üretme. Yayını durdur ve doğrulanmış anahtarı şifreli yedeğinden
geri getir. İlk mağaza yüklemesinden önce keystore ile Keychain parolalarının
ayrı, şifreli ve geri yüklemesi denenmiş bir yedeğini oluştur.

## 2. Release AAB derle

> ⚠️ Daha önce bir **debug** build aldıysan, release'ten önce `flutter clean`
> çalıştır. Aksi halde debug'dan kalma `GeneratedPluginRegistrant.java`,
> release'te bulunmayan `integration_test` (dev-dependency) paketini arar ve
> derleme "package dev.flutter.plugins.integration_test does not exist" hatası
> verir. `flutter clean` registrant'ı release için doğru yeniden üretir.

```bash
flutter clean
flutter build appbundle --release \
  --dart-define-from-file=.env.mobile.release.json
```

- RevenueCat anahtarları release derlemesinde zorunludur; eksikse uygulama
  açılışta yapılandırma hatası gösterir. Debug derlemede premium mock mod
  kullanılabilir.
- Çıktı: `build/app/outputs/bundle/release/app-release.aab` → Play Console'a
  yükle.

## 3. Üretilen imzayı her seferinde doğrula

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab
```

`jar verified` görülmeden AAB'yi Play Console'a yükleme. Play App Signing
açıksa bu dosya upload key'dir; Google dağıtım anahtarını ayrıca yönetir.

## İlgili

- Kod küçültme kuralları: `android/app/proguard-rules.pro`
- Play gönderim kontrol listesi: `docs/play_console_submission_checklist.md`
- iOS/masaüstü gereksinimleri: `docs/multi_platform_release.md`
- Gizlilik/koşullar URL'leri: `AppConfig.privacyPolicyUrl` /
  `AppConfig.termsOfServiceUrl` (uygulama içi linkler bunlara bağlı; sayfalar
  yayında olmalı).
