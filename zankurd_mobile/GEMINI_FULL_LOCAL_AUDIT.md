# ZanKurd tam yerel onarım raporu — 22 Temmuz 2026

## Sonuç

Denetimde doğrulanan derleme, platform yapılandırması, online oda güvenliği,
erişilebilirlik, responsive düzen, soru bankası, dil ve depo hijyeni sorunları
küçük ve test edilebilir paketlerle onarıldı. Supabase migration'ı ve doğrulanmış
web release Hostinger'a canlı uygulandı; push yapılmadı.

## Uygulanan ana düzeltmeler

- Tema, çark, turnuva bracket'ı, bildirim API'si ve paylaşım API'sindeki
  derleme/analyzer hataları düzeltildi.
- iOS galeri izin açıklaması eklendi; Windows yol uyumluluğu için kullanılan
  paket override'ları gerçek üst sınırlarla sabitlendi; Android desugaring
  güncellendi.
- Online oda soruları doğru cevap taşımayan RPC'ye geçirildi. Cevap doğrulama,
  tek gönderim, puanlama, oda soru aidiyeti ve hazır durumu sunucu sözleşmesine
  taşındı. İstemci ağ hatasında yerel puan yazmıyor.
- Solo, kategori, favori ve günlük akışlar deterministik offline runtime
  bankasını kullanıyor; doğrudan cevap-bearing uzak soru okumaları kaldırıldı.
- Metin ölçeği 2.0'a çıkarıldı; gizli sekmeler lazy oluşturuluyor; dar web
  kabındaki yanlış desktop kararı düzeltildi; ana sayfa mobil sliver sözleşmesi
  kararlı hale getirildi.
- Offline banka 3.147 kayıttan 2.347 benzersiz kayda indirildi. JSON ve Dart
  çıktısı tek deterministik üreticiye bağlandı. Varsayılan komut salt okunur,
  mutasyon yalnız `--fix` ile yapılır.
- Runtime banka kalite sonucu: exact duplicate 0, yapısal hata 0, yüksek güvenli
  cevap sızıntısı 0, yüksek güvenli dil karışımı 0. Orta güvenli 1.247 yakın
  tekrar ve 292 dinamik-tarih adayı uyarı olarak editoryal incelemeye bırakıldı.
- 10 binlik eski import bankası ve 49 publish adayı güvenli biçimde karantinaya
  alındı; uygulama/runtime gate'ine girmiyor fakat tam raporda görünmeye devam
  ediyor.
- Kurmancî ürün terimleri `Kûpa`, `Serhêl` ve `Ne li serhêl` olarak
  tutarlılaştırıldı.
- Runtime'da okunmayan 1,36 MB JSON asset bundle'dan çıkarıldı. Derlenmeyen stale
  Widgetbook ve artık yanlış yönlü olan eski exporter kaldırıldı.
- Soru kalite gate'i tam tarihsel raporu tekrar hesaplamıyor; güncel gate:
  2.367 runtime kayıt, 0 blocker, 0 critical, unknown source 0.

## Güncel doğrulama

- `dart analyze`: 0 bulgu.
- `flutter test --exclude-tags preview`: 642 geçti, 1 preview etiketi nedeniyle
  atlandı.
- Soru kalite gate: geçti; regresyon yok.
- `flutter build web --release`: geçti; Hostinger canlı hash'i yerelle eşleşti.
- `flutter build apk --debug --no-pub`: geçti.
- Web `main.dart.js` SHA-256:
  `71AF09EE9A0A0120D4886F31A2330C581A6454C932241E61608FA234F93929EC`.
- Debug APK SHA-256:
  `717290D03F982E95BA34E82E3031F2DB7D84BA90445A1BDE55B3464D6AE2078C`.
- Gerçek Chrome/browser-use: canlıda onboarding, anonim giriş, profil adı ve ana sayfa
  akışı çalıştı; 320x568, 390x844, 844x390, 768x1024 ve 1440x900 ölçülerinde
  yatay taşma yok; reload sırasında JS/runtime/network hata olayı 0.

## Bilinçli sınırlar

- Güvenlik migration'ı canlıya uygulandı ve şema/izin sözleşmesi sorguyla
  doğrulandı; iki gerçek hesaplı multiplayer smoke testi ayrıca yapılmalıdır.
- iOS derlemesi Windows'ta üretilemedi. Plist ve kaynak sözleşmesi testli olsa da
  gerçek iOS archive macOS üzerinde alınmalıdır.
- Android release signing ve mağaza yüklemesi yapılmadı. İmzalama dosyaları Git
  tarafından ignore ediliyor ve raporlara credential yazılmıyor.
- Flutter, `firebase_analytics` ve `in_app_review` için gelecekte Built-in Kotlin
  geçişi gerekeceğini bildiriyor; bu bugün derlemeyi engellemiyor.
