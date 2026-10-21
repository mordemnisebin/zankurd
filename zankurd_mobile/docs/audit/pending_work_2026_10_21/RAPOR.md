# ZanKurd kalan yerel işler — 21 Ekim 2026

## Tamamlananlar

1. **Arkadaş ekleme ile ödül kodu ayrıldı.** Arkadaş araması en üstte; ödül kartı “Davet ödülü / Xelata vexwendinê” olarak ayrı. Ödül düğmesi “Ödül kodu gir / Koda xelatê” ve jeton simgesi kullanıyor. Oda davetinin `K.inviteFriends` metni korunuyor. Supabase anonim misafir için oyuncu koduyla arama→arkadaş isteği yolu test edildi; ödül redeem çağrısı bu akışta sıfır, misafirin ödül düğmesi gizli. Bu, gerçek sunucu RPC testinin yerine geçmez.
2. **Günlük mod “Günün turu / Gera rojê” oldu.** Giriş, ekran başlığı, hata/boş durum, yardım, tanıtım ve başarı metinleri birlikte eşitlendi. “Günün dersi / Dersa rojê” korundu. Bireysel 10 soruluk tur için sıralama/yarışma/ödül vaadi eklenmedi; akış ve süre değiştirilmedi. İki dil modeli metni kontrol etti; tekil Kurmancî fiil uyumu uygulandı.
3. **Sabah selamı sorusunun tek doğru cevabı netleşti.** Yalnız `ders_2026_10_01_0003.answers[3]` ve `answersTr[3]`: Silav/Merhaba → Spas/Teşekkürler. Genel selam sabah da doğru olabildiği için seçenek belirsizdi. Doğru cevap Rojbaş değişmedi. Tam karar `content-decision.json` içinde; tartışmalı “Ku der” yanlış şıkkı ve üslup önerileri değiştirilmedi.
4. **Ek kanıtlı hata giderildi.** Enter ile peş peşe aramalarda eski, yavaş sonuç son aramanın oyuncusunu değiştirebiliyordu. Hata regresyon testiyle yeniden üretildi; sonuç, hata mesajı ve loading kapanışı yalnız güncel aramaya aitse uygulanıyor.

## Doğrulama

| Kapı | Sonuç |
|---|---|
| dart analyze ve Dart MCP | No issues / No errors |
| dart format | 1021 dosya, 0 değişiklik |
| Yeni regresyonlar | Eski kodda 3 hata + ters arama testi kırıldı; düzeltme sonrası geçti |
| Son hedef paket | 86 test geçti |
| Tam Flutter test paketi | **4939 geçti, 5 feature-flag testi atlandı; hata yok** |
| Cihazsız uygulama akışları | 4 geçti |
| Ekran turu | 174 test geçti; 179 PNG üretildi |
| Soru kalite kapısı | Geçti; blockers 0→0, criticals 0→0, issues 183→183; parmak izi güncellendi |
| Şık kalite taraması | 22 banka / 3750 soru / 0 bulgu; mevcut bulgu dosyası yazılmadı |
| Dokunma hedefi kaynak taraması | Göz gerektiren bulgu 0 |
| Web debug build | Geçti; JavaScript hedefi |
| Mobil ve web production config validator | İkisi de geçti; anahtar değerleri yazdırılmadı |
| Bağımsız kod ve görsel inceleme | Yeni P1/P2/regresyon bulgusu yok |

`ci_yerel.sh --tam` Git kullanan geri alma satırı nedeniyle doğrudan çalıştırılmadı. Format, analiz, içerik, a11y, ekran turu, tam test ve integration adımları ayrı yürütüldü. Git/GitHub kullanılmadı.

Önce/sonra kareler `before/` ve `after/` içinde. Ürün tasarım dili korunuyor. Kurmancî uzun ödül düğmesi ilk testte iki satıra kırıldı; metin “Koda xelatê” olarak kısaltıldı, tek satır bekçisi korundu ve geçti.

## Gerçek tarayıcı kontrolü ve kapsamı

Güncel ana uygulama development/offline web build olarak açıldı. Çevrimiçi eylemler offline oturumda kilitli olduğu için değişen ekranlar ayrıca geçici, yalnız test verisi kullanan `/tmp/zankurd_pending_preview.dart` entrypoint'inden **aynı üretim FriendsScreen/ContestScreen widget'larıyla** web'e derlendi. Bu entrypoint üretim kaynaklarına eklenmedi.

Playwright: 320×568 Kurmancî kayıtlı arkadaş ekranı ve ödül diyaloğu; 768×1024 misafir arkadaş ekranı; 390×844 Kurmancî günlük tur. Kayıtlıda ödül diyaloğu açılıp iptal edildi; misafirde arama/paylaşma açık, ödül kodu düğmesi yok; günlük tur başlığı “Gera rojê”. Örneklerde DOM yatay taşması yok, konsol hata 0. İlgili PNG'ler `after/browser-*.png` içinde. Widget responsive testleri canvas içi taşmayı ayrıca denetliyor.

Bu kontroller gerçek Supabase yazımı, ödeme, bildirim, fiziksel cihaz veya mağaza binary eşleşmesini doğrulamaz.

## Dış kapılar ve araştırma sonucu

- Yerel cihaz/emülatör listesi boş. `.release-device-evidence.json` yok; gerçek cihaz/Roundtrip/mağaza kanıtı tamamlandı olarak işaretlenmedi. Bulut cihaz ayrılmadı ve ücretli kaynak açılmadı.
- Build34 kaynak sürümü `2.0.4+34` değişmedi. Bu yeni kodun mağaza binary'sine dahil olduğu iddia edilmiyor. Yükleme/yayın veya canlı Supabase değişikliği yapılmadı. Repository, route, polling, realtime, matchmaking ve quiz mantığı değiştirilmedi.
- Web build'deki Wasm dry-run uyarısı uygulama kodundan değil, kilitli `flutter_tts 4.2.5` paketinin `flutter_tts_web.dart:104–107` JS interop cast'lerinden geliyor. [Resmi changelog](https://pub.dev/packages/flutter_tts/changelog) bu sürümün Android namespace düzeltmesini listeliyor; mevcut sürüm için yayımlanmış Wasm düzeltmesi doğrulanamadı. JavaScript web build geçiyor. Uyarı gizlenmedi; pub-cache veya dependency sürümü değiştirilmedi. Wasm ayrıca hedeflenecekse paket düzeltmesi ve TTS runtime testi ayrı doğrulanmalı.
- Önceki koyu ana sayfa P3 yorumu bu değişiklikte kritik hata olarak doğrulanmadı; gerekçesiz tema/refactor yapılmadı.

## Dosyalar

Tam değişen dosya listesi ve son SHA-256 değerleri `changed-files.json` içinde. Üretim değişikliği dört dosya ve kalite parmak iziyle sınırlı; üç yeni regresyon test dosyası var. İlgili eski testlerin metin beklentileri eşitlendi. `pubspec.yaml` ve `pubspec.lock` başlangıçla birebir aynı. Var olan ilgisiz yerel değişiklikler korunuyor.

Başlangıç içerik yedekleri `/tmp/zankurd-pending-20261021-before/` altında; bu bir Git yedeği veya release snapshot'ı değildir.
