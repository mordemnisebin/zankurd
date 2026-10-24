# 21 Ekim 2026 — Orkestra ve ZanKurd genel kontrolü

## Sonuç

OpenCode heyeti mevcut kurulumun üzerine iyileştirildi ve gerçek model çağrılarıyla sınandı. Uygulamada yalnız altı test dosyasındaki 12 mekanik analyzer uyarısı düzeltildi. Ürün mantığı, soru bankası, sürüm, canlı veritabanı ve mağaza durumu değiştirilmedi. Git/GitHub kullanılmadı.

## Orkestra düzeni

- Kaynak: `~/.config/opencode/orkestra/heyet.py`, katalog `heyet.json`, kullanım `~/.config/opencode/AGENTS.md`.
- Varsayılan iki ücretsiz üye; rol, gerçek erişim ve gecikmeye göre seçim. `balanced` bir ücretsiz + güçlü kota üyesi; `critical` kritik bağımsız görüşler. Puanlar başlangıç rol tahminidir; kalite benchmarkı değildir.
- Paralellik varsayılan 2, üst sınır 4; tur başına yedek ve sentez dahil varsayılan 4, azami 12 çağrı. Üye sınırı 90sn, turun toplam sınırı 240sn. Bu sınırlar tur başınadır; eşzamanlı bağımsız turların ortak günlük bütçesi değildir.
- Süreç kodu, JSON hatası, izin/kimlik/kota hatası, boş/kesilmiş yanıt ayrıdır. Bunlar başarılı görüş sayılmaz; yedekler farklı üyelerden seçilir. Yetersiz üye sayısında tamamlandı sonucu üretilmez.
- Yalnız başarılı yanıtlar ve özgün kaynak satırları senteze girer. `ok` yalnız yanıt alındığını, `verified` ayrıca belirlenmiş kontrolü geçtiğini ifade eder. `--expect` birebir duman testi içindir; genel doğruluk değerlendirmesi değildir.
- 2MB işlem çıktısı ve 120000 byte istem sınırı, iptal/timeoutta süreç grubunun kapatılması, sağlık geçmişi ve soğuma uygulanır.
- OpenCode danışmanının tüm araç izinleri kapalı; Claude araç/MCP kapalı; Codex shell kapalı, kullanıcı config'i olmadan read-only; AGY plan+sandbox ve dar bağlamla çalışır. AGY için bu, tam dosya sistemi izolasyonu iddiası değildir.
- Modeller dosya yazmaz; kaynakla karşılaştırıp düzeltmeyi şef uygular. Aynı dosyaya paralel model yazımı yoktur.
- Yeni OpenCode oturumlarında `orkestra-sef` ve OpenRouter ücretsiz Lightning modeli seçilir. Anahtar yeni kopyalanmadı; mevcut yerel dosyaya referans verilir. Önceden açık oturumun modeli değişmiş sayılmaz.
- Önceki ayarlar: `~/.config/opencode/orkestra/backups/20261021-041025/`. Mevcut diğer provider/MCP ayarları ve yerel ajan korundu.

## Gerçek erişim ve kalite gözlemleri

| Üye/kanal | Bu çalışmadaki kanıt | Sınır |
|---|---|---|
| North Mini Code / OpenRouter free | Birebir Hawar marker testi geçti | Büyük kod incelemesi token sınırında kesildi; görüş sayılmadı |
| Nemotron Lightning / OpenRouter free | Birebir Hawar marker testi geçti | Büyük kaynak ve sentez denemelerinde timeout/token sınırı görüldü; davet yorumunda yanlış çıkarımlar vardı |
| OpenCode native Lightning | Yeni araçsız ajanla birebir bağlantı testi geçti | Doğrudan API üyesiyle aynı model; bağımsız ikinci oy değildir |
| Claude CLI | Marker, kaynaklı dil incelemesi, kaynaklı sentez geçti | Abonelik kotası; her soru için çağrılmaz |
| AGY Gemini Flash | Araç istemeden marker ve verilen bağlam incelemesi döndü | Önceki dosya erişim izin hatasını sınırsız yetki vererek çözmedik |
| AGY Gemini Argon | İlk15 dil incelemesini verilen kaynakla yaptı | Üslup önerisi kesin hata değildir |
| AGY Opus | Günlük ders/yarış ayrımını kaynak satırlarıyla inceledi | Kota; canlı davranış kanıtı değildir |
| Codex CLI | Kod yöneticisinde iptal/çıktı sınırı gibi gerçek sorunları bildirdi; düzeltildi | Son araçsız smoke ayrıca logda |
| ChatGPT Chrome | Yerel canlı ref + tamamlanmış yanıt adapter'ıyla iki satır eksiksiz döndü | Manuel kanal; otomatik paralel havuzda değil |
| Gemma free | 429 gerçek sağlayıcı limiti | Soğuma; sınırsız tekrar yok |
| Inkling free | Agentic-harness 403 | Otomatik seçim dışında; kısıt aşılmadı |
| Nemotron Super free | Sağlayıcı 404 | Otomatik seçim dışında |
| OpenCode Zen ücretsiz üyeleri | CLI üzerinden FreeTierError/403 | Otomatik seçim dışında; katalogda görünmek erişim kanıtı değil |
| Xing free | Kısa yanıtta î harfini düşürdü | Kurmancî görevi verilmez; kod kalitesi henüz ölçülmedi |

Ücretsiz modellerde eksik veya hatalı yanıtlar görüldüğü için yalnız çoğunlukla karar verilmez. Kritik karar, kaynak ve testle doğrulanır. Ücretsiz API rotası `:free` kimliğiyle sınırlıdır; ücretli API veya plan etkinleştirilmedi.

## Uygulama doğrulamaları

| Kontrol | Sonuç |
|---|---|
| Dart MCP tam proje analizi | No errors; 12 info temizlendi |
| dart format --output=none --set-exit-if-changed | 1018 dosya, 0 değişiklik |
| 6 değişen test dosyası | 20 test geçti |
| flutter test --no-pub -r failures-only | 4933 geçti, 5 atlandı; tüm diğer testler geçti |
| Soru kalite kapısı | Borç artışı yok; 23 kaynak / 3795 fiziksel / 3753 kanonik kapsam |
| Şık kalite taraması | Manifestodaki 22 banka, 3750 kayıt, 0 bulgu; rapor dosyası yeniden yazılmadı |
| Dokunma hedefi kaynak taraması | Göz gerektiren bulgu 0; gerçek piksel/a11y ölçümü değildir |
| Cihazsız integration_test/app_flows_test.dart | 4 geçti |
| Ekran turu | 174 render/test geçti; 10 temsil karesine bağımsız görsel inceleme yapıldı |
| Web debug build | Geçti; flutter_tts 4.2.5 için Wasm dry-run uyumsuzluk uyarıları var; Wasm build iddia edilmiyor |
| Playwright yerel offline tarama | 390x844 ana sayfa, 320x568 Yarış; tanıtım→TR→misafir→ana sayfa→Yarış gezinmesi; DOM yatay taşma yok, konsol hata 0 |
| Orkestra Python testleri | 33 geçti; süreç iptali, TERM yok sayma, çıktı/süre sınırı, eksik üye, soğuma, ayrıştırma ve çok satırlı Chrome yanıtı dahil |

5 atlama: turnuva ve haftalık lig feature flag kapıları. Ayrıca sunucu soru CSV dışa aktarımı yokken sunucu-içerik testi yerel olarak veri denetleyemediğini açıkça yazıyor; canlı içerik temizliği iddia edilemez.

`ci_yerel.sh --tam` doğrudan çalıştırılmadı: içinde `git checkout` var ve Git yasak. Format, analiz, kalite, şık, a11y, ekran turu, tam test ve cihazsız akış adımları ayrı koşturuldu. Git adımı ve bulgu dosyasını geri alma yapılmadı.

Web yerel/offline açıldı; "Sunucuya ulaşılamadı" bandı bu konfigürasyonda beklenir. Çevrimiçi oda, gerçek hesap, ödeme, push, fiziksel cihaz ve mağaza binary eşleşmesi doğrulanmış sayılmaz. Test ekranındaki DOM taşma ölçümü Flutter canvas içi tüm taşmaları tek başına kanıtlamaz; responsive/widget testleri ayrı kanıttır.

## Öncelikli kalan işler

1. **Davet kodu ile arkadaşlık farklı işler.** `lib/src/screens/friends_screen.dart:545` misafirde kod düğmesini gizler. Diyalog `:1319` yalnız `redeemReferralCode` çağırır; repository `:3662` ödül RPC'sidir. Kod bozdurmak kendiliğinden arkadaşlık eklemez. Ödülün doğrulanmış hesap kapısı korunmalı. Arkadaş ekleme isteği mevcut sosyal akış üzerinden ayrı tasarlanmalı; canlı fonksiyon gövdesi görülmeden göç üretilmez. Ücretsiz modelin bu akışta "arkadaşlık entegre edilir" yorumu kaynakla doğrulanmadığı için kabul edilmedi.
2. **Günlük ders/yarış adlandırması.** `strings.dart:366,829,1315,2180`; `home_screen.dart:925` süresiz öğrenme akışı, `contest_screen.dart:98` süreli yarış akışı. Birbiriyle karışabilecek adlar var. Mevcut Kurmancî terminolojiye uygun tek yarış adı, tüm ilgili etiketler ve metin bekçileri birlikte ele alınmalı. Dil modelleri farklı karşılıklar önerdi; sırf çoğunlukla toplu metin değiştirilmedi.
3. **İlk15 soru: dil editörü kesinleştirmesi.** Önceki “Ku der → Ku derê” bulgusu kasıtlı yanlış şık olabileceği için otomatik uygulanmadı. Son kaynaklı inceleme kesin hata üzerinde uzlaşmadı; sabah selamında “Silav” seçeneğinin belirsizliği ve bağımsız ___ işaretleri pedagojik adaylar. `(id, alan)` bazında doğrulanmış karar ve kalite kapısı gerekir.
4. **Build34 harici kanıtı.** `pubspec.yaml` 2.0.4+34; paket dokümanı mevcut. Yüklenen binary, App Privacy ve fiziksel cihaz videosunun aynı build ile eşleşmesi açık kapıdır. Bu çalışma yükleme/yayın yapmadı.
5. **Düşük öncelikli görsel aday.** Tester koyu ana sayfa karesinde bazı ikincil bölüm başlıkları sönük görünüyor; bağımsız incelemede P3. Yerel tarayıcı örneğinde kritik engel yok; ölçüm ve önce/sonra kanıt olmadan tema değiştirilmedi.
6. **Web Wasm uyumu.** Güncel JavaScript web build çalışıyor. flutter_tts kaynaklı dry-run bulguları için paket sürümü/API araştırması ve hedefli Wasm testi ayrı iş; paket yükseltilmedi.

Supabase applied.md yalnız yerel kayıt olarak incelendi; bekleyen işaret görünmedi. Bu, canlıya yeni bağlanıp fonksiyon ve veri doğrulaması yapıldığı anlamına gelmez.

## Dosyalar ve kanıt

Değişen uygulama dosyaları yalnız: `test/sonuc_ritim_test.dart`, `test/kilitli_metin_okunur_test.dart`, `test/sonuc_puan_alt_satir_aralik_test.dart`, `test/kart_ust_etiketi_tek_dil_test.dart`, `test/kurul10_gece_ikincil_ve_ucret_notu_test.dart`, `test/kurul5_sayac_test.dart`.

Yanındaki loglar ve iki Playwright PNG bu raporun kanıtıdır. 174 kaynak görüntüsü `/tmp/zankurd-20261021-screen-tour/` altındadır; geçici klasör kalıcı teslim değildir. Model çağrı kayıtları `~/.config/opencode/orkestra/log/<tur-id>/run.json`; kaynak dosya hash ve satır aralıklarını içerir. API anahtarları bu rapora kopyalanmadı.
