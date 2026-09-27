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
      1931,
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
      1150,
      reason:
          'Oyuncuya ulaşan soru sayısı değişti. Fiziksel sayı sabit kalıp bu '
          'sayı düştüyse bir banka sessizce oynanamaz hâle gelmiştir: '
          'metadata `needsReview`e kaymış ya da yapısal bir alan bozulmuş '
          'olabilir. İkisi birlikte arttıysa yeni içerik gerçekten ulaşıyor.',
    );
  });

  test('engellenen kayıtların gerekçesi bilinen ve beklenen gerekçe', () {
    // Gerekçesiz engelleme, sessiz içerik kaybıdır: sorunun yapısı bozulmuş
    // olabilir ve hiçbir sayı bunu ele vermez. Burada her engelin nedeni
    // adlandırılır; beklenmeyen bir neden çıkarsa test düşer.
    final byReason = <String, int>{};
    for (final q in blocked) {
      final issues = policy.validate(q);
      // Gizli kategori kendi başına bir gerekçedir: o kayıtlar sağlam ve
      // onaylı olabilir, yalnız bilerek gösterilmez.
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
      // artık gizli kategori gerekçesiyle sayılıyor.
      'reviewStatus=${ReviewStatus.rejected}': 13,
      // 2026-09-27: bilerek gizlenen iki kategori (gerekçe
      // `category_visibility.dart` başında). Onaylı, reddedilmiş ve
      // kuyruktaki bütün kayıtları dahil.
      'hiddenCategory=Siyaset': 152,
      'hiddenCategory=Paradigma': 150,
      'hiddenCategory=Teknolojî': 217,
      // 2026-09-27 içerik denetimi: Kürtlerle bağı olmayan dünya bilgisi.
      // 2026-09-27 ikinci denetim: `offline_tf_` tanım takası kalıbında
      // farklı türden çift (87) + Ziman'da hiç "Rast" örneği olmayan kalıp
      // (10) + üç ayrı doğrulanmış kayıt (sf_cin_0053, cinema_0036 Kürt bağı
      // olmayan sinema; offline_7011 kopya şık).
      // Sînema 97->99 (+2), Cografya 23->53 (+30), Edebiyat 1->10 (+9);
      // Dîrok, Muzîk, Ziman, Çand ilk kez bu ikinci gerekçeyle giriyor.
      'retired=Sînema': 99,
      'retired=Cografya': 53,
      'retired=Edebiyat': 10,
      'retired=Dîrok': 17,
      'retired=Muzîk': 12,
      'retired=Ziman': 10,
      'retired=Çand': 20,
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
    expect(
      byCategory.length,
      7,
      reason: 'Kategori sayısı değişti: ${byCategory.keys.toList()..sort()}',
    );
  });
}
