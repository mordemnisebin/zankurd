import 'package:flutter_test/flutter_test.dart';
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
      // 2026-08-24: expansion_2026_08_19 (77 soru) eklendi. FİZİKSEL
      // sayı arttı ama oynanabilir sayı ARTMADI — kayıtlar
      // `needsReview` ve çapraz kontrolleri sırada (A5). Bu ayrım tam
      // olarak bu testin varlık sebebi: iki sayının birlikte artması
      // içeriğin gerçekten ulaştığını, yalnız fizikselin artması ise
      // kuyrukta beklediğini söyler.
      3042,
      reason:
          'Yüklenen kayıt sayısı değişti; `expansion_activation_test` ile '
          'birlikte güncellenmeli.',
    );
    expect(
      playable.length,
      // 3208 -> 2914: tekrar ayıklaması 294 kayıt aldı, hepsi
      // oynanabilir kayıtlardı (engellenenlerin dağılımı değişmedi,
      // aşağıdaki test onu ayrıca sabitliyor).
      2914,
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
      final key = issues.isNotEmpty
          ? issues.join(',')
          : 'reviewStatus=${q.metadata?.reviewStatus}';
      byReason[key] = (byReason[key] ?? 0) + 1;
    }

    expect(byReason, {
      // 37 -> 114: expansion_2026_08_19'un 77 kaydı kuyrukta.
      'reviewStatus=${ReviewStatus.needsReview}': 114,
      'reviewStatus=${ReviewStatus.rejected}': 14,
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
    expect(
      byCategory.length,
      10,
      reason: 'Kategori sayısı değişti: ${byCategory.keys.toList()..sort()}',
    );
  });
}
