# T5 — Yerel doğrulama ve teslim

30 Ekim 2026. Önceki sandbox engelleri bu oturumda aşıldı. Canlı veritabanına bağlanılmadı, göç uygulanmadı, push yapılmadı. Anahtar/kimlik dosyaları incelenmedi. Çalışma dosyaları bu worktree içinde tutuldu.

## Commitler

- `ae73e27d` — önceki oturumun geçiş ritmi, uygulanmamış göç ve bekçileri.
- `536adb22` — soru/reveal için RPC anında sunucu saati, saat farkı, monoton süre; eski snapshot yarışı.
- `278ce66d` — üç meydan okuma sonucunu yeni yanlış cevap beklemesine uyarlama.
- `c1f6f4cb` — hazır yanıtı gelmeden yanıltıcı tam süre göstermeme; erişilebilir bekleme etiketi.
- `dd24b84b` — ekran kapanınca açıklama Timer'ını iptal etme, bekleyen Future'ı çözme.

## Kök neden ve çözüm

Soru sayacı sunucunun `remaining_ms` değerini oda/profil sorguları tamamlandıktan sonra yeniden başlatıyordu. Aradaki gecikme kayboluyor; sonraki geçen süre `DateTime.now` farkıyla hesaplanıyordu. Sunucu zaman damgaları zaten mevcut olduğundan soru saati için yeni RPC gerekmedi.

`ServerClock`, RPC yanıtı gelir gelmez `server_now + RTT/2 - local_received_at` farkını ölçer. Sonraki zaman yalnız monoton `Stopwatch` ile ilerler. Oda/profil yükleme, ekran kurulumu ve gecikmiş olaydan sonra kalan süre ortak sunucu deadline'ından hesaplanır. Soru ve reveal aynı saat örneğini kullanır; cihaz duvar saati sonraki geri sayımı değiştirmez.

Hazır işaretleme ve reconciliation paralel dönebildiğinden, aynı sorunun eski `server_now` örneği yeni deadline'ı silebiliyordu. Eski örnek artık uygulanmaz. Hazır yanıtı beklenirken de varsayılan 30 gibi sahte bir süre yerine mevcut bekleme göstergesi kullanılır; yeni TR/KU dizesi eklenmedi.

Tam CI ekran turu ayrı bir yaşam döngüsü kusurunu yakaladı: yanlış cevap açıklamasındaki `Future.delayed` ekran kapanınca iptal olmuyordu. Süre artık ekranın sahip olduğu Timer ile tutulur; dispose hem Timer'ı iptal eder hem bekleyen Future'ı çözer. Testin beklemesi uzatılarak hata gizlenmedi.

## Kanıt

- İki saniye bekletilmiş snapshot: düzeltme öncesi beklenen 18 yerine **20** saniye; düzeltme sonrası geçti.
- Eski waiting yanıtı: düzeltme öncesi çalışan sayaç durdu (`isAnimating == false`); düzeltme sonrası geçti.
- Hazır yanıtı gecikmesi: yanlış tam süre yerine bekleme göstergesi; yanıt gelince geçen iki saniye düşülür.
- Erken ekran kapanışı: düzeltme öncesi Flutter binding `A Timer is still pending...` ile kırıldı; düzeltme sonrası geçti.
- `t5_server_clock_test.dart`: ±5 saniye cihaz saati, 2 saniye geç olay, farklı RTT, ortak deadline ve kaçan tick bekçileri.
- Hedef doğrulamaları: 119 saat/repository/oda testi; 71 oda/meydan okuma testi; 37 oda testi; son yaşam döngüsü düzeltmesiyle 66 düello/turnuva testi geçti. Bunlar aşağıdaki tam CI'ın yerine sayılmadı.
- Son komut: `cd zankurd_mobile && ./tool/ci_yerel.sh --tam` (`TMPDIR` worktree içinde).
- Tam CI: **214 ekran turu + 7.000 ana test (3 atlandı) + 4 cihazsız uygulama akışı geçti; çıkış kodu 0.**
- Son satır: **CI yerel: bütün adımlar geçti.**
- Son çıktı özeti: [t5_ci_sonuc.txt](t5_ci_sonuc.txt).

İlk tam taramada üç eski meydan okuma helper'ı kırıldı. O tur sürerken kod değiştiği için bir test dosyası eski derleme önbelleğiyle yüklenemedi; bu tur son doğrulama sayılmadı. Sonraki tam tur ekran kapanışı Timer kusurunu buldu. Bunun ardından 6.999 test geçti; tek kırık, benim verdiğim `TMPDIR` yolundaki `..` bileşenini dağıtım güvenlik bekçisinin reddetmesiydi. Test/üretim kodu değiştirilmedi: `TMPDIR=/Users/kocer/Projects/zk-astra-gecis/.local-tmp` mutlak yolu ile aynı bekçi geçti. Yukarıdaki son tam CI bu ayarla, sabit kaynak durumunda baştan çalıştırıldı.

## Değiştirilen eski testler ve gerekçeleri

| Dosya | Değişiklik / gerekçe |
|---|---|
| `test/async_duel_screens_test.dart` | Ortak ilerleme helper'ı 1300 → 3100 ms: ilk seçenek yanlış olabilir. TIMEOUT testi 2999 ms'de hâlâ aynı soruda, +1 ms'de sonraki soruda olmayı ayrıca doğrular. Yeni erken dispose bekçisi eklendi. |
| `test/duello_sirasi_istemci_test.dart` | Süresi dolmuş resume senaryosu 1500 → 3100 ms bekler; TIMEOUT açıklamasının yeni 3 sn sözleşmesi. Cevap sayısı doğrulaması korunur. |
| `test/friend_challenge_ui_test.dart` | Ortak helper 1300 → 3100 ms: bağlantı paylaşımı, arkadaş sonucu ve bağlantı kabulü testleri gerçekten yedi soruyu tamamlar. Sonuç ve paylaşım beklentileri değişmedi. |
| `test/quiz_room_resume_test.dart` | Mevcut doğrulamalar korunarak ortak reveal, son soru, gecikmiş snapshot, ters yanıt sırası ve hazır bekleme bekçileri eklendi; kontrollü saat/yanıt destekleri genişletildi. |
| `test/supabase_repository_test.dart` | Eski/yeni reveal alanı ve RPC'den sonraki iki saniyelik oda yükleme gecikmesini sınayan testler eklendi. |
| `test/turnuva_sunucu_puani_istemci_test.dart` | Yanlış cevabın 2999 ms'de kaybolmadığı, 3000 ms'de ilerlediği bekçi eklendi. |
| `tool/screenshots/screen_tour_test.dart` | Yalnız eski 1200 ms yorumları güncellendi. Ekran100'ün 2 saniyelik kapanış beklemesi aynen kaldı; Timer sızıntısı üretim kodunda giderildi. |

Hiçbir sonuç/paylaşım/puan doğrulaması gevşetilmedi. Yeni bağımsız dosyalar: `t5_server_clock_test.dart`, `t5_reveal_timing_test.dart`, `t5_gecis_sql_test.dart`.

## Görsel kontrol ve sınırı

Gerçek `QuizScreen`, yerel sahte repository ile Flutter web debug derlemesinde Playwright üzerinden iki ayrı 390×844 istemcide açıldı. A için +5 sn, B için −5 sn cihaz saati örneği; B için 2 sn veri gecikmesi enjekte edildi. Sistem saati değiştirilmedi. Hazırdan sonra 25/25, 24/24 ve kayıtlı karede **15/15** görüldü. Taşma görülmedi; son tarayıcı oturumunda konsol hatası yoktu.

- [İki istemci ekranı](t5_iki_istemci.png)
- [Aynı anın erişilebilirlik ağacı](t5_iki_istemci_snapshot.txt)

Bu kanıt canlı sunucu veya fiziksel iki cihaz deneyi değildir. Native simülatör turu bu oturumda yapılmadı. Geçici web harness'i ve çalışma dosyaları kaldırıldı; ekran kanıtları bu klasörde tutuldu.

## Uygulanmayan göç ve açık riskler

- `supabase/2026-10-30_gecis_ritmi.sql` **YAZILDI, UYGULANMADI**; `supabase/applied.md` kaydı ⏳ olarak kaldı. Göç eski tam fonksiyonu kopyalamaz; uygulama anındaki canlı `pg_get_functiondef` üzerinde tekil çıpaları değiştirir, tanım saparsa transaction'ı durdurur. Bu oturumda SQL motorunda veya canlıda çalıştırılmadı.
- Soru deadline/saat düzeltmesi mevcut API alanlarını kullanır. Ortak reveal bitiş alanı gelmeyen eski sunucuda 5 sn yedek davranışı sürer; canlı reveal eşitlemesi göçün ayrıca doğrulanıp uygulanmasına bağlıdır.
- RTT/2 simetrik aktarım tahminidir. Aşırı asimetrik ağ veya uzun sunucu işlem süresinde ±1 sn genel garantisi yoktur. Geç ulaşan soru içeriğinin fiziksel görüntülenme anı da eşitlenmiş olmaz; gelen istemci kalan süreyi doğru hesaplar.
- Uygulama öncesi canlı fonksiyon diff'i, begin/rollback SQL duman testleri ve gerçek iki cihaz ölçümü hâlâ gereklidir. Bu işlemler burada yetki dışıdır.
- Aynı sağlayıcıdan bağımsız ikinci göz saat, snapshot yarışı, bekleme göstergesi ve Timer yaşam döngüsü farklarını inceledi; son kontrolde engelleyici bulgu kalmadı. Farklı sağlayıcıdan Claude/Gemini onayı alınmadı; böyle bir onay varmış gibi sunulmadı.
- Web derlemesinde `flutter_tts` bağımlılığının WASM deneme uyarıları görüldü; kullanılan JavaScript debug derlemesi başarılıydı. Release/store hazır oluşu iddia edilmedi.
