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
];
