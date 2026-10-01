import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

import 'support/widget_test_helpers.dart';

/// Her seviye, kartında YAZAN soru sayısını gerçekten verebilmeli.
///
/// ## Niçin bu bekçi var
///
/// 2026-08-16 taramasında kullanıcıyı gerçekten yaralayan kusurların çoğu kod
/// hatası değildi, içerik kaynaklıydı: "Dil › Kelime Bilgisi › 1. Seviye"
/// kartı "10 soru" diyor, tur tek soruda bitiyordu. Kod tarafı 2200'den fazla
/// bekçiyle savunulmuş durumda; soru bankası ise en az korunan ve en çok
/// değişen parça — her içerik dalgası havuz dengelerini sessizce kaydırıyor.
///
/// `round_length_floor_test` seçim kodunun havuzu boşa harcamadığını bağlar.
/// Bu dosya bir üst katmanı bağlar: **havuzun kendisi yeterli mi.** İkisi
/// birlikte, "10 soru" yazısının bir vaat değil bir olgu olmasını sağlar.
///
/// ## Neyi ölçer, neyi ölçmez
///
/// İlk test (`her kategori × seviye…`) `QuestionBankLoader` JSON
/// varlıklarını hiç tetiklemez; ölçülen havuz üretimdeki tam banka değil,
/// depodaki küratörlü fixture'dır. Yani bu bir TABAN güvencesidir: fixture
/// bile seviyeleri dolduramıyorsa üretim bankası da dolduramaz. Üretim
/// bankasının kendi denetimi `tool/question_quality/question_quality_audit.dart`
/// kapısındadır.
///
/// İkinci test (`alt kategoriler…`) 2026-09-28'den beri GERÇEK bankayı
/// yükler (bkz. `subcategory_pool_width_test.dart`, aynı önlem): küçük
/// fixture'da hiçbir alt kategori `kMinSubcategoryQuestions` eşiğini
/// aşamaz, yani ekran hiçbirini göstermez — fixture'la ölçüm "kartın
/// göstermediği bir şeyin seviyesini doldurabiliyor mu" gibi anlamsız bir
/// soru sorardı.
///
/// ## Kural
///
/// Ekranda ne yazıyorsa odur: kart `questionCount` gösteriyorsa tur o
/// kadar soru döndürmeli. Havuz yetersizse test, hangi kategori/seviyenin
/// hangi sayıda kaldığını söyler — düzeltme içerik tarafında yapılır, kullanıcı
/// tarafında değil.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('her kategori × seviye ilan ettiği soru sayısını verebiliyor', () async {
    final repository = freshMockRepository();
    final shortfalls = <String>[];

    for (final category in repository.categories) {
      for (final level in repository.levelsForCategory(category)) {
        final questions = await repository.loadLevelQuestions(
          category: category,
          difficultyMin: level.difficultyMin,
          difficultyMax: level.difficultyMax,
          limit: level.questionCount,
        );
        if (questions.length < level.questionCount) {
          shortfalls.add(
            '$category › ${level.title} (${level.number}. seviye): '
            'kart ${level.questionCount} diyor, havuz ${questions.length} '
            'verebiliyor',
          );
        }
      }
    }

    // BİLİNEN açık (2026-09-30): ürün sahibi Paradigma'yı yeniden açtı ve
    // tek bir siyasi hareketin öğretisini doğru cevap diye sunan sorular tek
    // tek emekliye ayrıldı (`retired_question_ids.dart`, "Dördüncü dalga").
    // Paradigma'nın zorluk 4-5 bandında oynanabilir soru 13'e indi; 5.
    // seviye kartı 15 diyor. Tur yine oynanır (13 soru), "tek soruda
    // tamamlandı" durumu YOK — ama kart 2 soru fazla vaat ediyor. Çözüm
    // içerik tarafında: Paradigma'ya en az 2 kaynaklı zor soru yazılınca
    // ya da kart sayısı bu kategori için düşürülünce bu satır SİLİNİR. Test
    // açığın aynı kalmasını bağlar: başka bir seviye düşerse ya da bu açık
    // büyürse yine kırılır.
    //
    // KAPANDI (2026-09-30 son birleştirme): 40 kaynaklı bilim sorusu
    // (`bilim_2026_09_30_questions.json`) Paradigma'nın zor bandına da soru
    // ekledi (zorluk 4-5: 7 soru); 5. seviye artık 15 soruyu veriyor. Liste
    // boş: bundan sonra HERHANGİ bir açık yeni bir gerilemedir.
    const knownShortfalls = <String>[];

    expect(
      shortfalls,
      knownShortfalls,
      reason:
          'Bu seviyeler kartlarında yazan soru sayısını veremiyor; oyuncu tek '
          'soruda "tamamlandı" ekranını görür (beklenen tek bilinen açık: '
          '$knownShortfalls):\n${shortfalls.join('\n')}',
    );
  });

  test('alt kategoriler de kendi seviyelerini doldurabiliyor', () async {
    // 2026-09-28: bu test eskiden `freshMockRepository()`ın küçük curated
    // fixture'ıyla (~45 soru, 8 kategoriye dağılmış) TÜM yapılandırılmış alt
    // kategorileri geziyordu. O fixture ile artık hiçbir alt kategori
    // `kMinSubcategoryQuestions` eşiğini aşamaz (böyle küçük bir bankada
    // hiçbir konu 20 gerçek eşleşmeye ulaşmaz) — yani kart hiçbirini hiç
    // GÖSTERMEZ. Ekranın göstermediği bir alt kategorinin seviyesini
    // doldurup dolduramadığını ölçmek yanlış soruyu sorar; bu yüzden bekçi
    // artık gerçek bankayı yükler (bkz. subcategory_pool_width_test.dart,
    // aynı önlem) ve yalnız GÖRÜNÜR alt kategorileri gezer.
    expect(QuestionBankLoader.instance.allQuestions.length, greaterThan(1000));
    final repository = freshMockRepository();
    final playable = repository.playableQuestions;
    final shortfalls = <String>[];

    for (final category in repository.categories) {
      final visible = SubcategoryConfig.visibleFor(category, playable);
      for (final subcategory in visible) {
        // Yalnız ilk seviye ölçülür: en dar bant odur (zorluk 1-2) ve
        // yetersizlik önce orada görünür. Bütün seviyeleri × bütün alt
        // kategorileri gezmek testi gereksizce uzatırdı.
        // 2026-10-02: kart alt konunun GERÇEK boyutunu söyler (bkz.
        // [SubcategoryLevelPlan]); 10 sabiti yerine o sayı sorulur.
        final level = repository
            .levelsForCategory(category, subCategory: subcategory.id)
            .first;
        shortfalls.add('$category/${subcategory.id}/${level.questionCount}');
      }
    }

    // Ölçüm eşzamanlı yapılamadığı için liste yukarıda toplanıp burada
    // sırayla sürülür.
    final failures = <String>[];
    for (final entry in shortfalls) {
      final parts = entry.split('/');
      final category = parts[0];
      final subcategory = parts[1];
      final wanted = int.parse(parts[2]);
      final level = repository
          .levelsForCategory(category, subCategory: subcategory)
          .first;
      final questions = await repository.loadLevelQuestions(
        category: category,
        difficultyMin: level.difficultyMin,
        difficultyMax: level.difficultyMax,
        subCategory: subcategory,
        levelNumber: level.number,
        limit: wanted,
      );
      if (questions.length < wanted) {
        failures.add(
          '$category › $subcategory: kart $wanted diyor, '
          '${questions.length} geliyor',
        );
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'Bu alt kategoriler ilk seviyeyi dolduramıyor:\n'
          '${failures.join('\n')}',
    );
  });
}
