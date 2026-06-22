# ZanKurd — Build & Test Notları (BUILD_AND_TEST_NOTES)

> Son güncelleme: 2026-06-22
> Projeyi yerelde doğrulamak ve release build almak için komutlar. Windows + Türkçe karakterli kullanıcı yolu için özel notlar içerir.

---

## Ortam

- Flutter: **3.44.1** (stable)
- Dart: **3.12.1**
- Ana proje dizini: `zankurd_mobile/`

## Windows — Kritik Yol & TMP/TEMP Uyarısı

Bu makinenin kullanıcı yolu Türkçe **`İ`** karakteri ve boşluk içeriyor: `C:\Users\AMARGİ\Desktop\pirs kurmanci`. Bu iki sorun yaratır:

1. **`flutter analyze` çöker** (LSP byte-stream hatası — Türkçe `İ` UTF-8'de 2 bayt, `Content-Length` desenkronize olur). **Çözüm: `dart analyze` kullan** (LSP kullanmaz, sorunsuz çalışır).
2. **Gradle/build loopback hatası ve native (jni/CMake/aapt) bozulması.** Çözüm: build öncesi TMP/TEMP ayarla; mümkünse **ASCII build yolundan** (`C:\src\zankurd_mobile`) build al.

### PowerShell (önerilen, Windows)

```powershell
# 1) Geçici dizin ve TMP/TEMP ayarı (Gradle loopback fix)
New-Item -ItemType Directory -Force -Path 'C:\src\tmp'
$env:TMP  = 'C:\src\tmp'
$env:TEMP = 'C:\src\tmp'

# 2) Proje dizinine geç
cd 'C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile'

# 3) Bağımlılıklar
flutter pub get

# 4) Statik analiz  (flutter analyze DEĞİL — dart analyze)
dart analyze

# 5) Testler
flutter test

# 6) (İsteğe bağlı) Biçimlendirme kontrolü (dosya değiştirmez)
dart format --output=none --set-exit-if-changed lib/ test/
```

### Bash (Git Bash) eşdeğeri

```bash
export TMP="C:/src/tmp"
export TEMP="C:/src/tmp"
mkdir -p /c/src/tmp
cd "C:/Users/AMARGİ/Desktop/pirs kurmanci/zankurd_mobile"
flutter pub get
dart analyze
flutter test
```

## Release Build (APK / AAB)

> **Öneri:** Native build adımlarının Türkçe/boşluklu yolda bozulmaması için kaynağı ASCII bir yola kopyalayıp oradan build al: `C:\src\zankurd_mobile`.

```powershell
New-Item -ItemType Directory -Force -Path 'C:\src\tmp'
$env:TMP  = 'C:\src\tmp'
$env:TEMP = 'C:\src\tmp'

# APK (release)
flutter build apk --release

# Play Store için AAB (release) — final yükleme artefaktı
flutter build appbundle --release

# İmza doğrulaması
jarsigner -verify -verbose -certs 'build/app/outputs/bundle/release/app-release.aab'
```

Beklenen sonuçlar (final AAB üretmeden önce):

- `dart analyze`: **No issues found!**
- `flutter test`: tüm testler geçer
- AAB: `build/app/outputs/bundle/release/app-release.aab` oluşur
- `jarsigner`: `jar verified`
- Hedef SDK: API 35+ (mevcut yapı API 36 hedefliyor)

## İmzalama (Güvenlik)

- Release imzalama, **takip edilmeyen yerel dosyalarla** yapılır: `android/key.properties`, `android/upload-keystore.jks`.
- Bu dosyalar gizlidir; **paylaşılmaz, loglanmaz, dokümana yazılmaz**, güvenli yedeklenir. Şablon: `android/key.properties.template`.

## Supabase ile Çalıştırma (opsiyonel)

Yapılandırma verilmezse uygulama otomatik **Mock** moda düşer. Gerçek backend için:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<proje>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

## React Web Prototipi (ikincil, `zankurd/`)

```bash
cd zankurd
npm install
npm run lint
npm run build   # tip kontrolü + Vite build
npm run dev     # :5173
```

## Son Doğrulanan Sonuçlar (2026-06-22)

- `flutter pub get`: başarılı (exit 0) — 28 paketin kısıtlarla uyumsuz daha yeni sürümü var (bilgi amaçlı, kritik değil).
- `dart analyze`: **No issues found!**
- `flutter test`: **All tests passed!** (225/225)
