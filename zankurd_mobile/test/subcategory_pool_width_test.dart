import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/category_visibility.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

/// Üretim bankası yüklüyken HER vaat edilen tur tam uzunlukta kurulabilmeli.
///
/// ## Niçin var
///
/// `round_length_floor_test` süzgeçlerin *mekanizmasını* yapay bir bankayla
/// doğrular; `subcategory_screen_test` kartların çizildiğini. Hiçbiri
/// **üretim bankasıyla** kategori × alt kategori × seviye matrisinin
/// tamamında tur uzunluğunu ölçmez. Dar bir alt kategori havuzu (ör.
/// "Rêziman" anahtar kelimeleriyle eşleşen az soru) yalnız matrisin tek
/// hücresinde kısalık üretir; mekanizma testleri o hücreyi hiç kurmaz.
///
/// Bu bekçi yazılırken iki sessizlik tuzağı ortaya çıktı ve ikisi de
/// aşağıda kapatıldı:
///
/// 1. Testte `QuestionBankLoader.instance.load()` çağrısı rootBundle
///    olmadığından her asset'i sessizce boş döndürür; yükleyici "yüklendi"
///    işaretini yalnız curated 45 soruyla kaldırır. Bu hâlde matrisin
///    75 hücresi kısa düşer — üretimde var olmayan bir alarm. Bekçi bu
///    yüzden `load()` DEĞİL, `allQuestions` tetiklediği senkron test
///    yüklemesini kullanır ve kütüphanenin gerçekten şişkin olduğunu
///    (>= 2000 soru) ayrıca doğrular; aksi hâlde dar küme üzerinde
///    kendiliğinden geçerdi.
/// 2. Seçim kodu boş DEĞİLSE yedeğe düşer; "biraz kısa" tur geçerli
///    sayılır ve kalite bekçileri (tekrar/sızıntı yok) kısalmış turda da
///    kolayca geçer. Ancak bu bekçi tam uzunluğu şart koşar.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // `load()` burada YANLIŞ olur: test koşucusunda rootBundle yoktur, her
    // asset sessizce boş döner ve yalnız curated banka yüklenir. Test
    // ortamında gerçek bankalar `allQuestions` tetiklediğinde senkron
    // dosya okumayla gelir (bkz. question_bank_loader_io.dart).
    expect(QuestionBankLoader.instance.allQuestions.length, greaterThan(2000));
  });

  test(
    'her görünür kategori×alt kategori×seviye tam tur uzunluğu verir',
    () async {
      final repository = MockZanKurdRepository();
      final failures = <String>[];

      for (final category in visibleCategories(repository.categories)) {
        final subcategories = SubcategoryConfig.subcategories[category];
        if (subcategories == null || subcategories.isEmpty) continue;

        for (final level in repository.levelsForCategory(category)) {
          for (final sub in subcategories) {
            final questions = await repository.loadLevelQuestions(
              category: category,
              difficultyMin: level.difficultyMin,
              difficultyMax: level.difficultyMax,
              subCategory: sub.id,
              limit: level.questionCount,
            );
            if (questions.length < level.questionCount) {
              failures.add(
                '$category › ${sub.id} › seviye ${level.number}: '
                '${questions.length}/${level.questionCount}',
              );
            }
          }
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    },
  );
}
