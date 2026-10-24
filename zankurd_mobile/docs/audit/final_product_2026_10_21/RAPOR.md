# ZanKurd son ürün taraması ve yerel geliştirmeler — 21 Ekim 2026

## Sonuç

Resmî Duolingo, Busuu ve Drops kaynakları, mevcut ZanKurd kaynakları ve Orkestra görüşleri birlikte değerlendirildi. Mevcut ders yolu, yerleştirme, dinleme, sözlük, kısa oturum ve SM-2 tekrar özellikleri korundu. Kanıtlanan dört davranış alanında küçük düzeltmeler yapıldı; yeni tasarım sistemi, oyunlaştırma veya büyük refactor eklenmedi.

Karşılaştırma ve kaynaklar: [REFERANSLAR.md](REFERANSLAR.md). Kaynak farkı: [changes.patch](changes.patch). Son dosya hashleri: [changed-files.json](changed-files.json).

## Uygulananlar

1. **Tekrar başlatma güvenilirliği.** Aynı karede çift dokunuş tek oturum başlatır. İşlem bittiğinde/hata olduğunda kilit açılır; ekran kapanmışsa UI/callback çalıştırılmaz. Başka akışta tüketilmiş tekrarlar artık bayat kartta asılı kalmaz. Başlatma hatası kaydedilir ve mevcut yerelleştirilmiş hata mesajı gösterilir. Üretim metinleri değişmedi.
2. **Arkadaş isteğinde hemen yeniden deneme.** Kabul/red isteğinin gecikmeli false veya exception sonucunda busy durumu yeniden çizilir; eylemler bir sonraki polling turunu beklemeden açılır. Çift gönderim bekçileri, arama epoch düzeltmesi ve ödül/arkadaş ayrımı korunur.
3. **Günlük turda dürüst hata durumu.** Sekiz saniyelik timeout artık gerçek boş içerik sayılmaz; mevcut hata ve yeniden dene yolu kullanılır. Gerçek null sonuç hâlâ boş durumdur. Süre, soru sayısı veya quiz kuralları değişmez.
4. **16 doğrulanmış başlangıç dersinin çevrimdışı tamamlaması eşitlenir.** UUID ve doğrudan sunucu slug çözümü önceliklidir; bulunamazsa yalnız açık izinli yerel ders slug'ı denenir. Üç seed'deki 18 adayın 16'sında slayt sayısı/sırası, Kurmancî-Türkçe içerik ve örnek metinler birebir eşleşti; testler bu pariteyi sabitler. Ağ bağlantısı gelince bekleyen Alfabe tamamlamasının doğru UUID ile onaylanıp kuyruktan çıkması mock HTTP + SyncManager ile doğrulandı.

İlk genel alias yaklaşımı son anlamsal incelemede daraltıldı. Soru kapsamının örtüşmesi, ders tamamlamasının eşdeğer olduğunu kanıtlamaz: `culture_2`, `geography_1`, `grammar_1`, birleşik dersler, ayrıca içeriği farklı `greetings_2` ve `intro_1` otomatik eşitlenmez. Bu kimliklerin yerel ilerlemesi silinmez veya karşılıkları tahmin edilmez. Kapsam farkı giderilmeden bunlar için sunucu tamamlaması vaat edilmiyor.

## Doğrulama

- **Son kaynaklarla tam Flutter paketi: 4975 geçti, 5 özellik bayrağı testi atlandı; hata yok.** Genel paket izinlistesi daraltılıp 16 parite testi sabitlendikten sonra yeniden çalıştırıldı.

- Dart MCP ve doğrudan `dart analyze`: temiz. `dart format`: 1020 dosya, 0 değişiklik.
- Son izinlistesi hedef paketi: 69/69. Tekrar ve async paketleri: 19/19. Yeni davranışlar eski kodda kırmızı testlerle kanıtlandı.
- Ekran turu: 174 test geçti; 179 PNG. Cihazsız uygulama akışları: 4/4.
- Soru kalite kapısı geçti: 23 kaynak / fiziksel 3795 / kanonik 3753 / unknown 0. Mevcut borç: blockers 0, criticals 0, issues 183; soru bankası ve baseline değiştirilmedi.
- Şık taraması: 22 banka / 3750 soru / 0 bulgu; rapor dosyası yazılmadan aynı scan fonksiyonu çalıştırıldı. Dokunma hedefi kaynak taramasında göz gerektiren bulgu 0.
- Son ana uygulama JavaScript web debug build geçti (`/tmp/zankurd-final-web`). Son derlemede yalnız JS hedefi istendi; önceki Wasm dry-run günlüğü ayrıca saklandı. Mevcut `flutter_tts 4.2.5` JS interop uyarısı çözülmüş sayılmıyor.
- Mobil ve web production config validator geçti; anahtar değerleri yazdırılmadı veya değiştirilmedi.
- Bağımsız kod/görsel inceleme ve son Orkestra Claude review: yeni P1/P2 bulgu yok. Bu, tüm uygulamanın açık içermediği iddiası değildir.

`ci_yerel.sh --tam` Git komutu içerdiğinden doğrudan çalıştırılmadı. Eşdeğer format/analiz/içerik/a11y/ekran turu/test/integration adımları ayrı yürütüldü. Git veya GitHub kullanılmadı.

## Gerçek tarayıcı kanıtı

Playwright, aynı test verisiyle orijinal yedek widget ile güncel üretim widget'ını karşılaştırdı. Geçici `/tmp/zankurd_final_preview.dart` ve yalnız import yolları uyarlanmış orijinal kaynak kopyaları kullanıldı; fixture üretim koduna eklenmedi. Soru bankası normal loader ile yüklendi.

- 390×844 Türkçe: timeout önce boş durum, sonra hata→Tekrar→10 soruluk tur; arkadaş kabulü önce pasif kalıyor, sonra hata sonrası yeniden etkin; bayat tekrar kartı önce kalıyor, sonra tamamlandı durumuna geçiyor.
- 320×568 Kurmancî koyu tema: günlük tur hata→Dîsa→gerçek tur kartı.
- 768×1024 Kurmancî koyu tema: arkadaş kabulü başarısızken yeniden etkin Qebûl.
- 1280×800: son ana uygulama build'inin gerçek ilk açılışı (fixture değil), Kurmancî tanıtım ve yaş kapısı çizildi.
- İncelenen DOM'da yatay taşma yok; konsol errors 0. Canvas içi düzen için PNG'ler ve widget ekran turu ayrıca incelendi.

Aynı klasördeki before/after PNG'ler davranış farkını gösterir. Bağımsız inceleme Türkçe dört kareyi, kök inceleme Kurmancî telefon/tablet karelerini değerlendirdi. Kritik taşma/kırpılma yok. Arkadaş ekranındaki geçici Snackbar alttaki boş durum metninin bir bölümünü kısa süre örtebilir; temel eylemleri engellemiyor.

## Sınırlar

Yerel cihaz/emülatör listesi boş; `.release-device-evidence.json` yok. Gerçek Android/iOS, fiziksel cihaz TTS/bildirim/satın alma, canlı Supabase ve mağaza binary eşleşmesi doğrulanmadı. Mock HTTP/fixture kanıtı canlı servis başarısı değildir.

Sürüm `2.0.4+34` korundu. Canlı veritabanı, migration, mağaza yükleme/yayın, ücretli kaynak veya hesap açma yapılmadı. Yayınlanmış uygulamanın bu değişiklikleri içerdiği söylenmiyor. Bu teslim, test edilmiş yerel kaynakların son halidir; 183 içerik borcunun editoryal kapanışı veya sınırsız kapsamlı bir güvenlik denetimi değildir.
