# ZanKurd release readiness — 22 Temmuz 2026

## Karar

**Web ve Supabase canlı yayın: başarılı. Mobil mağaza yayını: koşullu.**

Kod, test, web yayını ve Supabase güvenlik kapıları geçti. Mobil mağaza yayını
için aşağıdaki platform adımları ayrıca tamamlanmalıdır.

## Geçen kapılar

- Analyzer: temiz.
- Test: 642 geçti, 1 preview testi bilinçli atlandı.
- Soru kalite gate: 2.367 aktif runtime kayıt; 0 blocker, 0 critical, unknown 0.
- Web release build: başarılı; geliştirme JSON bankası bundle'da yok.
- Hostinger: HTTP 200; canlı ve yerel `main.dart.js` SHA-256 eşleşiyor.
- Supabase: migration canlıda; güvenli soru görünümü, üç RPC, dar izinler ve
  `TIMEOUT` kısıtı sorguyla doğrulandı.
- Android debug APK: başarılı.
- Chrome smoke: onboarding → anonim auth → ad girişi → ana sayfa başarılı;
  responsive yatay taşma yok ve reload hata olayı yok.
- iOS fotoğraf kitaplığı açıklaması mevcut.
- Signing credential dosyaları Git'te izlenmiyor ve ignore ediliyor.

## Yayından önce zorunlu

1. İki gerçek hesapla cevap gizleme, tek gönderim, puan ve hazır durumunu
   cihazlar arası smoke-test et.
2. Gerçek Android release keystore ile AAB üret, imzayı doğrula ve Play Console
   pre-launch raporunu kontrol et.
3. macOS üzerinde iOS archive al; galeri izin metnini gerçek cihazda doğrula.
4. Karantinadaki import/publish soru dosyalarını otomatik olarak canlıya alma;
   ancak editoryal temizlik ve ayrı kalite onayından sonra çıkar.
5. Plugin'lerin Built-in Kotlin uyumluluğunu bir sonraki Flutter yükseltmesinden
   önce takip et.

## Artefaktlar

- Web: `build/web/`
- Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`
- Web JS SHA-256:
  `71AF09EE9A0A0120D4886F31A2330C581A6454C932241E61608FA234F93929EC`
- APK SHA-256:
  `717290D03F982E95BA34E82E3031F2DB7D84BA90445A1BDE55B3464D6AE2078C`
