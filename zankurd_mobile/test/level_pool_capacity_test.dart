import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';

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
/// Test koşucusunda `QuestionBankLoader` JSON varlıklarını yüklemez; bu yüzden
/// ölçülen havuz üretimdeki tam banka değil, depodaki küratörlü fixture'dır.
/// Yani bu bir TABAN güvencesidir: fixture bile seviyeleri dolduramıyorsa
/// üretim bankası da dolduramaz. Üretim bankasının kendi denetimi
/// `tool/question_quality/question_quality_audit.dart` kapısındadır.
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

    expect(
      shortfalls,
      isEmpty,
      reason:
          'Bu seviyeler kartlarında yazan soru sayısını veremiyor; oyuncu tek '
          'soruda "tamamlandı" ekranını görür:\n${shortfalls.join('\n')}',
    );
  });

  test('alt kategoriler de kendi seviyelerini doldurabiliyor', () async {
    final repository = freshMockRepository();
    final shortfalls = <String>[];

    SubcategoryConfig.subcategories.forEach((category, list) {
      for (final subcategory in list) {
        // Yalnız ilk seviye ölçülür: en dar bant odur (zorluk 1-2) ve
        // yetersizlik önce orada görünür. Bütün seviyeleri × bütün alt
        // kategorileri gezmek testi gereksizce uzatırdı.
        final level = repository.levelsForCategory(category).first;
        shortfalls.add('$category/${subcategory.id}/${level.questionCount}');
      }
    });

    // Ölçüm eşzamanlı yapılamadığı için liste yukarıda toplanıp burada
    // sırayla sürülür.
    final failures = <String>[];
    for (final entry in shortfalls) {
      final parts = entry.split('/');
      final category = parts[0];
      final subcategory = parts[1];
      final wanted = int.parse(parts[2]);
      final level = repository.levelsForCategory(category).first;
      final questions = await repository.loadLevelQuestions(
        category: category,
        difficultyMin: level.difficultyMin,
        difficultyMax: level.difficultyMax,
        subCategory: subcategory,
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
