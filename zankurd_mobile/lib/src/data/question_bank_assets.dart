/// Uygulamanın yüklediği JSON soru bankalarının TEK listesi.
///
/// ## Niçin var
///
/// Bu liste üç yerde ayrı ayrı yazılıydı: üretim yükleyicisinde
/// (`question_bank_loader.dart`), test yükleyicisinde
/// (`question_bank_loader_io.dart`) ve denetim araçlarında
/// (`tool/audit_*.dart`). Zamanla ayrıştılar — araçlar iki bankayı
/// tarıyordu, uygulama dördünü yüklüyordu.
///
/// Sonuç, sessiz bir kör nokta: `audit_option_languages.dart` tam da
/// "şıklardan biri doğru cevabın dilinde değil" kusurunu aramak için
/// yazılmıştı ve `editorial_questions.json`ı hiç açmıyordu — oysa
/// uygulama o bankayı yüklüyor. Denetim "temiz" diyordu çünkü baktığı
/// yerde kusur yoktu (2026-08-01).
///
/// Yeni bir banka eklendiğinde tek yer burasıdır; yükleyiciler ve araçlar
/// buradan okur, bir bekçi de üçünün ayrışmadığını doğrular.
library;

/// Yükleme sırası anlamlıdır: aynı `id` birden çok bankada varsa SONRAKİ
/// kazanır. Curated (Dart sabiti) her zaman en önde durur ve bu listede
/// yer almaz — o bir asset değil.
const questionBankAssets = <String>[
  'assets/data/sentence_building_questions.json',
  // 2026-08-10: gerçek yazılı cevap akışı için iki dilli, kaynaklı ve
  // editör denetimli 20 Ziman sorusu. `answers` şık listesi değil, tek
  // kanonik cevaptır; güvenli klavye varyantları `acceptedAnswers`dadır.
  'assets/data/fill_in_blank_2026_08_questions.json',
  'assets/data/community_questions.json',
  'assets/data/editorial_questions.json',
  'assets/data/offline_questions.json',
  // 2026-08-06 iki dilli genişletme: TR+KU soru, şık ve açıklama.
  // Kaynak ajan batch'lerinden deterministik yeniden kuruldu ve
  // `tool/content_authoring/normalize_content_typography.py` ile
  // yapısal olarak normalleştirildi (regex ile toplu onarım DEĞİL).
  'assets/data/expansion_2026_08_questions.json',
  // 2026-08-06 kaynak-önce genişletme: her soru doğrudan açılmış kurumsal
  // sayfadan (BFI, NASA, NOAA, USGS, NIST, Columbia, La Biennale, Berlinale,
  // MDN) çıkarılmış tek bir olguya dayanır ve gerekli Kurmancî terimleri
  // Wîkîferheng girdisiyle açılmıştır. Provenance:
  // docs/content/verified_external_pool_2026_08/provenance.json
  'assets/data/source_first_2026_08_questions.json',
  // 2026-08-07: kendi kategorisini soran döngüsel «kategori eşleştirme»
  // soruları çıkarılınca 29 görsel öksüz kaldı. Bunlar gerçek fotoğraflar —
  // dengbêj icrası, tembûr, erbane, arkeolojik kazı — ve çöpe atılmaları
  // israf olurdu. Yerlerine görselin GERÇEKTEN gösterdiği şeye dayanan soru
  // yazıldı: bir ajan görseli açıp yazdı, ikinci bir ajan görseli kendisi
  // açıp doğruladı. 29 görselin 20'si geçti; kalan 9'un görseli konuyla
  // uyumsuz çıktı (ör. `ritim.webp` Batı Afrika djembe'si gösteriyordu) ve
  // hem soru hem görsel elendi.
  'assets/data/visual_2026_08_07_questions.json',
  // 2026-08-07: çıkarılan 33 kaydın 20'si görsel soruyla karşılandı; kalan
  // 13'ü burada. Amaç sayıyı korumak değil, kaldırılan her konunun bankada
  // bir karşılığının kalması: dahol, zurna, kilam, bilûr, şabaş, kelaş,
  // metelok, hewran, Şerefname, Rojnameya Kurdistan, Çiyayê Cûdî, Deşta
  // Amedê. Terim tanımları bankanın kendi onaylı açıklamalarıyla birebir.
  'assets/data/restore_2026_08_07_questions.json',
  // 2026-08-18 DeepSeek dalgası (~1110 kayıt) dosya olarak durur ama
  // runtime listesinde YOKTUR: olgusal doğruluk örneklemle ~%5–8 hata
  // verdi. Oyuncuya yanlış olgu öğretmek, sayıyı şişirmekten pahalıdır
  // (2026-09-02 karantina). Yeniden almak için insan incelemesi + bu
  // listeye bilinçli ekleme gerekir. Cevap anahtarı bekçisi dosyayı
  // yine tarar. Bu dalgadan ayrıca incelenip künyelenen 77 soru ise
  // aşağıdaki dosyada, oyuncuya açık.
  'assets/data/expansion_2026_08_19_questions.json',
  // 2026-09-28: alt kategoriler yalnız gerçekten o konudaki soruları
  // gösterince yedisi 20 sorunun altında kalıp gizlendi (Rastnivîsîn,
  // Dastangotin, Tiştonek, Sînor û Dûmahî, Muzîka Nûjen, Yılmaz Güney û
  // Klasîk, Belgefîlm û Festîval). 144 soru onları açmak için yazıldı:
  // her olgu açılmış bir kaynaktan alıntıyla (URL `sourceReference`da),
  // her soru olgu, dil ve soru zanaatı gözüyle üç ayrı ajanca
  // doğrulandı, onarıldı ve son bir denetimden geçti. DeepSeek
  // dalgasının dersi (kaynaksız üretim ~%5–8 olgu hatası) burada kaynak
  // şartıyla karşılandı; Kurmancî metinler yine de ana dili Kurmancî olan
  // bir editörün okumasını bekliyor.
  'assets/data/expansion_2026_09_28_questions.json',
  // 2026-09-30: karantinadaki DeepSeek dosyasının (yukarıda, listede YOK)
  // çok modelli doğrulamadan geçen 458 sorusu. Orijinal dosya karantinada
  // KALIR ve tek bir kayıt bile oradan okunmaz; buraya yalnız şu iki şartı
  // birden sağlayanların KOPYASI girdi: (1) olgu denetimi — en az iki
  // bağımsız model (Gemini 3.8 Flash / Muse Spark, Grok 4.7, Space Bunny
  // eleği) hiçbir kusur işaretlemedi; (2) Kurmancî okuması — Gemini 3.1 Pro
  // (ya da Grok 4.7) uygun buldu. Olgu hatası örnekleme ile ~%5–8 çıkmıştı;
  // bu filtre o oranı soru bazında eler. Metin aynen korunur, yalnız
  // künye (`reviewedBy`, `reviewedAt`) eklenir. Genel bilgi sayılan sorular
  // (dünya sineması/coğrafyası/edebiyatı/müziği/tarihi) `Cîhan`
  // kategorisindedir; Kürt diliyle ve kültürüyle ilgili olanlar kendi
  // kategorisinde kalır.
  // Aynı gün ikinci tur: aynı filtreden geçen 364 soru daha eklendi; bunlarda
  // ayrıca Gemini 3.1 Pro'nun önerdiği, Grok 4.7 ya da Gemini 3.8 Flash'ın
  // onayladığı bir Kurmancî dil/terim düzeltmesi uygulandı (doğru şıkkın
  // KONUMU ve anlamı değişmedi; Türkçe alanlara dokunulmadı).
  'assets/data/deepseek_verified_2026_09_30_questions.json',
  // 2026-09-30: «Bilim ve Düşünce / Zanist û Raman» (iç kimlik Paradigma)
  // tek bir hareketin öğretisi emekli edilince 42 soruya inmişti; kalan
  // içerik de alt konuların çoğunu boş bırakıyordu. 40 yeni soru, her biri
  // açılmış bir web kaynağından (NASA, NIST, WHO, UN, Stanford Encyclopedia
  // of Philosophy…; URL `sourceReference`da) ChatGPT'yle taslaklandı,
  // Gemini 3.1 Pro Kurmancîye çevirdi, Grok 4.7 okudu. Konular: temel bilim,
  // felsefe tarihi, anayasa/BM/insan hakları, Kürt düşünce tarihi.
  'assets/data/bilim_2026_09_30_questions.json',
  // 2026-10-01: üç alt konu 20 oynanabilir soruya ulaşamadığı için kartı
  // gizliydi: Muzîk › Muzîka Nûjen (15), Teknolojî › Programkirin (16),
  // Sînema › Yılmaz Güney û Klasîk (18). 17 yeni soru, her biri açılmış bir
  // web kaynağından (Vikipedi, MDN, Python belgeleri, W3Schools, Eurasianet;
  // URL `sourceReference`da) MiMo-V2.6-Flash'la taslaklandı, Gemini 3.1 Pro
  // Kurmancîye çevirdi, Grok 4.7 olgu ve dil açısından okudu; doğrulanamayan
  // bir soru (Hozan Dîno albüm yılı) çıkarıldı.
  'assets/data/altkonu_2026_10_01_questions.json',
];
