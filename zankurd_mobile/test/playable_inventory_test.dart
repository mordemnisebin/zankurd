import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visibility.dart';
import 'package:zankurd_mobile/src/config/retired_question_ids.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// Oyuncunun GERÇEKTEN görebildiği soru sayısının bekçisi.
///
/// ## Kusur
///
/// "Uygulamada 2151 soru var" cümlesi 2026-08-07 denetimine kadar
/// doğrulanmamış bir cümleydi. `expansion_activation_test.dart` yükleyicinin
/// çıktısını sayıyor; oysa yükleyiciden çıkan her soru oynanabilir değil.
/// Arada iki süzgeç duruyor (`QuestionContentPolicy.isPlayable`):
///
///   1. `ContentQualityPolicy` — `reviewStatus` açıkça `approved` dışındaysa
///      soru elenir. Dikkat: bu, `requireApproved` kapalıyken de böyledir;
///      bayrak yalnız metadata'sı HİÇ olmayan eski kayıtlar için gevşetir.
///   2. Yapısal geçerlilik — görselli soruda görsel yoksa, çoktan seçmelide
///      dört şık yoksa, doğru cevap şıklarda değilse soru oynanamaz.
///
/// Ölçüldüğünde fark 61 kayıttı: `community_questions.json`'daki 15 kayıt
/// `rejected`, 46 kayıt `needsReview` durumundaydı. Yani banka onları
/// taşıyor, yükleyici onları sayıyor, kalite kapısı onları denetliyor —
/// ama oyuncu hiçbirini göremiyor. Hiçbir bekçi bu farkı ölçmüyordu, yani
/// yarın bir bankanın tamamı `needsReview` gelse fiziksel sayı artar,
/// testler yeşil kalır ve oynanabilir içerik hiç büyümez.
///
/// Bu bekçi farkı görünür kılar ve sabitler.
///
/// 2026-08-18: DeepSeek boru hattıyla 1298 iki dilli soru eklendi (bkz. question_bank_assets.dart). Sayaç bilerek güncellendi.
/// 2026-09-02: aynı banka olgusal hata yüzünden runtime'dan çıkarıldı (1110 kayıt).
void main() {
  const policy = QuestionContentPolicy();

  late List<QuizQuestion> loaded;
  late List<QuizQuestion> playable;
  late List<QuizQuestion> blocked;

  setUpAll(() {
    loaded = QuestionBankLoader.instance.allQuestions;
    playable = loaded.where(policy.isPlayable).toList();
    blocked = loaded.where((q) => !policy.isPlayable(q)).toList();
  });

  test('oynanabilir soru sayısı beklenen değerde', () {
    expect(
      loaded.length,

      // 2026-08-19: dış kalite denetimi bankalar arası 199 tekrar
      // kümesi buldu; her kümeden biri bırakılıp 294 kayıt elendi
      // (silinenler docs/content_batches/ayiklanan_tekrarlar.json).
      // Bekçinin işi değişmedi, saydığı banka küçüldü.
      // 2026-08-24: expansion_2026_08_19 (77 soru) eklendi; o gün
      // fiziksel arttı, oynanabilir artmadı — kayıtlar `needsReview`
      // ve çapraz kontrol kuyruğundaydı. A17 (2026-08-26) künye
      // verdi ve `approved` yaptı: oynanabilir 2914 → 2991. Bu
      // bekçinin varlık sebebi tam bu ayrım: iki sayı birlikte artınca
      // içerik gerçekten ulaşıyor.
      // 2026-09-02: DeepSeek 1110 kayıt runtime'dan çıkarıldı
      // (olgusal hata ~%5–8). Dosya durur; oyuncuya yüklenmez.
      // 2026-09-21: offline_2556 semantik tekrar olduğu için kaldırıldı.
      // 2026-09-28: expansion_2026_09_28 (144 soru) eklendi. Fiziksel ve
      // oynanabilir BİRLİKTE +144: kayıtlar kaynaklı ve `reviewStatus`
      // taşımıyor, yani kuyrukta beklemiyor, oyuncuya ulaşıyor.
      // 2075 -> 2937: 2026-09-30 son içerik birleştirmesi. Fiziksel +862:
      // çok modelli doğrulamadan geçen 822 DeepSeek sorusu kopya dosyada
      // (`deepseek_verified_2026_09_30`; orijinal karantinada kalır) ve 40
      // kaynaklı bilim sorusu (`bilim_2026_09_30`, Paradigma).
      // 2937 -> 2954 (+17): aynı gün üç ek iş. +31 üçüncü dalga (Kurmancî
      // düzeltmeli DeepSeek), -44 kaynağı bulunamayan ya da cevabı yanlış
      // çıkan DeepSeek kaydı karantinaya döndü (853 -> 809), +30 yeni
      // kaynaklı bilim sorusu (bilim_0041…0070). Kontrol: 31 - 44 + 30 = 17.
      // 2954 -> 2971 (+17): 2026-10-01 `altkonu_2026_10_01` — üç gizli alt
      // konuyu açan kaynaklı sorular. 2971 -> 3045 (+74): 2026-10-01
      // `ders_2026_10_01`, derse etiketli alıştırma soruları (bkz.
      // `lesson_practice_depth_test.dart`). 3045 -> 3048 (+3): aynı gün
      // yeniden yazılan üç ders sorusu. 3048 -> 3169 (+121): 2026-10-02
      // `bosluk_2026_10_02`; yeni dosyadaki kayıtlar fiziksel sayıya girer.
      3169,
      reason:
          'Yüklenen kayıt sayısı değişti; `expansion_activation_test` ile '
          'birlikte güncellenmeli.',
    );
    expect(
      playable.length,
      // 3208 -> 2914: tekrar ayıklaması 294 kayıt aldı.
      // 2914 -> 2991: A17, expansion_2026_08_19'un 77 kaydını
      // `approved` yaptı; oyuncuya ilk kez ulaşıyorlar.
      // 2991 -> 3000: 7 curated + Amed + YPJ. 12 sinema kaydı
      // mevcut bankalarla yakın tekrar olduğu için kuyrukta kaldı.
      // 3000 -> 1890: DeepSeek karantinası (1110 oynanabilir kayıt).
      // 1890 -> 1889: offline_2556 semantik tekrar olarak kaldırıldı.
      // 1889 -> 1588: 2026-09-27 Paradigma ve Siyaset gizlendi (301
      // oynanabilir kayıt). Kayıtlar bankada; gerekçe
      // `category_visibility.dart` başında.
      // 1588 -> 1250: aynı gün içerik denetimi. Teknolojî gizlendi (217)
      // ve dört kategorideki 121 dünya bilgisi sorusu emekliye ayrıldı
      // (`retired_question_ids.dart`: Sînema 97, Cografya 23, Edebiyat 1).
      // 1250 -> 1150: aynı gün, ikinci bir denetim. `offline_tf_` tanım
      // takası kalıbındaki 152 "Şaş" sorunun 87'si sorulan terimden farklı
      // TÜRDEN bir tanım taşıyordu (göl↔dağ, kişi↔çalgı, dergi↔kişi gibi) —
      // bilgi değil tür ipucu ölçüyordu; Ziman'da ise kalıbın hiç "Rast"
      // örneği yoktu (10 soru). Hepsi emekliye ayrıldı. Ayrıca
      // `sf_cin_0053`, `cinema_0036` (Kürt bağı olmayan sinema) ve
      // `offline_7011` (kopya şık) tek tek emekliye ayrıldı. Toplam -100.
      // Bkz. `retired_question_ids.dart`'ın "İkinci dalga" belgesi ve
      // `test/tf_definition_swap_test.dart`.
      // 1150 -> 1294: 2026-09-28 expansion_2026_09_28. Alt kategoriler
      // dürüstleşince 20 sorunun altında kalıp gizlenen yedi alt kategori
      // için 144 kaynaklı soru; hepsi oynanabilir.
      // 1294 -> 1204: 2026-09-29 doğallık: şablon izi denetimi 90 soruyu
      // emekliye ayırdı (sözlük D/Y 26, boş önerme 1, tür sızıntılı sözlük
      // çoktan seçmelisi 55, bozuk tanım 2, kopya çeldirici/ikinci kılıf 3,
      // Kürt bağsız sinema 3). Bkz. `retired_question_ids.dart`'ın
      // "Üçüncü dalga" belgesi. Fiziksel sayı değişmedi.
      // 1204 -> 1203: 2026-09-30 simülatör denetimi: "pir" (çok) sorusunun
      // görseli yaşlı bir adamdı ("pîr"), `offline_0120` emekliye ayrıldı.
      // Fiziksel sayı değişmedi.
      // 1203 -> 1721: 2026-09-30 ürün sahibi Paradigma, Siyaset ve Teknolojî'yi
      // yeniden açtı (+518 oynanabilir: 519 kayıt açıldı, biri reddedilmiş).
      // İdeolojik soruların tek tek emekliye ayrılması bu sayıyı ayrıca
      // düşürecek (`retired_question_ids.dart`).
      // 1721 -> 1563: aynı gün, o ayıklama yapıldı: tek bir siyasi hareketin
      // öğretisini doğru cevap diye sunan 159 Paradigma/Siyaset sorusu
      // emekliye ayrıldı (`retired_question_ids.dart`, "Dördüncü dalga").
      // Oynanabilir -158, çünkü 159'un biri zaten `rejected` idi (aşağıda
      // rejected 14 -> 13). Fiziksel sayı değişmedi.
      // 1563 -> 1546: 2026-09-30 beşinci dalga, bağımsız model ailesinin
      // (ChatGPT) ikinci geçişi: tartışmalı kavrama tek "doğru tanım"
      // dayatan ya da siyasi yüklü terime normatif tanım veren 17 Siyaset
      // sorusu emekliye ayrıldı (`retired_question_ids.dart`, "Beşinci
      // dalga"). Hiçbiri `rejected` değildi, yani oynanabilir tam -17.
      // Fiziksel sayı değişmedi.
      // 1546 -> 2469 (+923): 2026-09-30 son birleştirme.
      //   +862 yeni kayıt (822 doğrulanmış DeepSeek + 40 bilim), hepsi
      //   `approved` ve oynanabilir;
      //   +99 emekliden dönen dünya bilgisi (47 + 52 sinema/coğrafya/Don
      //   Kişot; `Cîhan` kategorisinde, bkz. `retired_question_ids.dart`
      //   «Cîhan'a dönenler»);
      //   -38 son olgu doğrulaması (altıncı dalga): Gemini 3.1 Pro ve Grok 4.7
      //   ikisinin de onayladığı 38 soru emekliye ayrıldı (hepsi mevcut
      //   bankalarda; yeni kopya dosyadan hiçbiri değil).
      // Kontrol: 862 + 99 - 38 = 923.
      // 2469 -> 2486 (+17): fiziksel sayıyla aynı üç iş (+31 üçüncü dalga,
      // -44 karantinaya dönen, +30 bilim); hepsi `approved` ve oynanabilir,
      // karantinaya dönen 44'ün hiçbiri retired değildi.
      // 2486 -> 2485 (-1): offline_tf_cog_0003 bilgi yanlışı ("Geliyê Botan
      // Cizîrê dorpêç dike" — Botan Vadisi Siirt'tedir) emekliye ayrıldı.
      // 2485 -> 2502 (+17): 2026-10-01 `altkonu_2026_10_01`; 2502 -> 2576
      // (+74): 2026-10-01 `ders_2026_10_01`, 14 dersin alıştırması için derse
      // etiketli sorular. Hepsi `approved` ve oynanabilir; fiziksel sayıyla
      // birlikte arttı (içerik gerçekten ulaşıyor). 2576 -> 2579 (+3): aynı
      // gün yeniden yazılan üç ders sorusu. 2579 -> 2700 (+121): 2026-10-02
      // `bosluk_2026_10_02`, hepsi `approved` ve oynanabilir (Cîhan zor
      // katman, Paradigma d5, Siyaset iki alt konu, doğru-yanlış dengesi).
      2700,
      reason:
          'Oyuncuya ulaşan soru sayısı değişti. Fiziksel sayı sabit kalıp bu '
          'sayı düştüyse bir banka sessizce oynanamaz hâle gelmiştir: '
          'metadata `needsReview`e kaymış ya da yapısal bir alan bozulmuş '
          'olabilir. İkisi birlikte arttıysa yeni içerik gerçekten ulaşıyor.',
    );
  });

  test('görseli anlamla çelişen "pir" sorusu oynanmaz', () {
    // 2026-09-30 simülatör: "pir" (çok) görseli yaşlı bir adam ("pîr").
    expect(isQuestionRetired('offline_0120'), isTrue);
    expect(playable.any((q) => q.id == 'offline_0120'), isFalse);
    expect(loaded.any((q) => q.id == 'offline_0120'), isTrue);
  });

  test('engellenen kayıtların gerekçesi bilinen ve beklenen gerekçe', () {
    // Gerekçesiz engelleme, sessiz içerik kaybıdır: sorunun yapısı bozulmuş
    // olabilir ve hiçbir sayı bunu ele vermez. Burada her engelin nedeni
    // adlandırılır; beklenmeyen bir neden çıkarsa test düşer.
    final byReason = <String, int>{};
    for (final q in blocked) {
      final issues = policy.validate(q);
      // Gizli kategori kendi başına bir gerekçedir: o kayıtlar sağlam ve
      // onaylı olabilir, yalnız bilerek gösterilmez. 2026-09-30'da liste
      // boşaldı; mekanizma dururken anahtar da durur (yeni bir gizleme
      // burada kendi satırını görür ve beklenen dağılım güncellenir).
      final key = !isCategoryVisible(q.category)
          ? 'hiddenCategory=${q.category}'
          : isQuestionRetired(q.id)
          ? 'retired=${q.category}'
          : issues.isNotEmpty
          ? issues.join(',')
          : 'reviewStatus=${q.metadata?.reviewStatus}';
      byReason[key] = (byReason[key] ?? 0) + 1;
    }

    expect(byReason, {
      // 37 -> 28: 2026-09-02 yedi curated Kurmancî yeniden yazıldı;
      // Amed ve YPJ kaynaklanıp onaylandı. 12 sinema kaydı mevcut
      // bankalarla yakın tekrar; 16 künyesiz topluluk + 14 rejected duruyor.
      'reviewStatus=${ReviewStatus.needsReview}': 28,
      // 14 -> 13: reddedilmiş bir kayıt gizlenen kategorilerden birinde;
      // gizli kategori gerekçesiyle sayılıyordu.
      // 13 -> 14: 2026-09-30 üç kategori yeniden açıldı, o kayıt yine
      // kendi gerekçesiyle (rejected) sayılıyor.
      // 14 -> 13: 2026-09-30 dördüncü dalga; reddedilmiş o kayıt
      // Paradigma'nın emekli listesine de girdi ve gerekçe olarak
      // `retired` önce sayıldığı için artık oradan sayılıyor.
      'reviewStatus=${ReviewStatus.rejected}': 13,
      // 2026-09-27 içerik denetimi: Kürtlerle bağı olmayan dünya bilgisi.
      // 2026-09-27 ikinci denetim: `offline_tf_` tanım takası kalıbında
      // farklı türden çift (87) + Ziman'da hiç "Rast" örneği olmayan kalıp
      // (10) + üç ayrı doğrulanmış kayıt (sf_cin_0053, cinema_0036 Kürt bağı
      // olmayan sinema; offline_7011 kopya şık).
      // Sînema 97->99 (+2), Cografya 23->53 (+30), Edebiyat 1->10 (+9);
      // Dîrok, Muzîk, Ziman, Çand ilk kez bu ikinci gerekçeyle giriyor.
      // 2026-09-29 doğallık (üçüncü dalga, şablon izi, 90 kayıt):
      // Sînema 99->102, Cografya 53->67, Edebiyat 10->16, Dîrok 17->36,
      // Muzîk 12->22, Ziman 10->36, Çand 20->32.
      // 2026-09-30 Cîhan: 99 kayıt emekliden çıkıp `Cîhan`a döndü (ilk tur
      // 47: Sînema 37, Cografya 9, Edebiyat 1; ikinci tur 52: Sînema 42,
      // Cografya 10) ve altıncı dalga (son olgu doğrulaması) 38 kayıt ekledi
      // (Çand 9, Edebiyat 8, Dîrok 7, Muzîk 5, Teknolojî 3, Siyaset 2,
      // Cografya 2, Sînema 2):
      //   Sînema 102 - 79 + 2 = 25; Cografya 67 - 19 + 2 = 50;
      //   Edebiyat 16 - 1 + 8 = 23; Dîrok 36 + 7 = 43; Muzîk 22 + 5 = 27;
      //   Çand 32 + 9 = 41; Teknolojî 0 + 3 = 3; Siyaset 68 + 2 = 70.
      'retired=Sînema': 25,
      'retired=Cografya': 51,
      'retired=Edebiyat': 23,
      'retired=Dîrok': 43,
      'retired=Muzîk': 27,
      // 2026-09-30: 36 -> 37 (`offline_0120`, görsel "pîr" gösteriyor).
      'retired=Ziman': 37,
      'retired=Çand': 41,
      // 2026-09-30 altıncı dalga: Teknolojî'den iki modelce onaylanan 3 soru.
      'retired=Teknolojî': 3,
      // 2026-09-30 dördüncü dalga: tartışmalı siyasi görüşü doğru cevap diye
      // sunan sorular (Paradigma 108, Siyaset 51). Bu iki kategori yeniden
      // açıldığı için ilk kez bu gerekçeyle giriyorlar.
      'retired=Paradigma': 108,
      // 2026-09-30 beşinci dalga (ChatGPT ikinci geçişi): Siyaset 51 -> 68
      // (+17: 8 çoktan seçmeli + 9 doğru/yanlış). Paradigma değişmedi.
      // 2026-09-30 altıncı dalga: +2 (68 -> 70).
      'retired=Siyaset': 70,
    }, reason: 'Engellenen kayıtların dağılımı değişti: $byReason');
  });

  test('her kategoride bir tur dolduracak kadar oynanabilir soru var', () {
    // Bir tur 10 soru; en az 40 soru "her zorluk gözünde bir tur" eşiğidir
    // ve `category_visibility.dart` bu eşikle kategori açıp kapatıyor.
    const roundThreshold = 40;
    final byCategory = <String, int>{};
    for (final q in playable) {
      byCategory[q.category] = (byCategory[q.category] ?? 0) + 1;
    }

    final thin = byCategory.entries
        .where((e) => e.value < roundThreshold)
        .map((e) => '${e.key}: ${e.value}')
        .toList();

    expect(
      thin,
      isEmpty,
      reason:
          'Bu kategorilerde bir tur doldurmaya yetecek oynanabilir soru yok. '
          'Kategori ya doldurulmalı ya `hiddenCategoryIds` ile gizlenmeli: '
          '${thin.join(", ")}',
    );
    // 10 -> 8: 2026-09-27 Paradigma ve Siyaset gizlendi.
    // 8 -> 7: aynı gün Teknolojî de gizlendi.
    // 7 -> 10: 2026-09-30 üçü de yeniden açıldı.
    // 10 -> 11: 2026-09-30 `Cîhan` (Dünya) kategorisi eklendi.
    expect(
      byCategory.length,
      11,
      reason: 'Kategori sayısı değişti: ${byCategory.keys.toList()..sort()}',
    );
  });
}
