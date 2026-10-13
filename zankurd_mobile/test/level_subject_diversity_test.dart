import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/data/subcategory_level_plan.dart';
import 'package:zankurd_mobile/src/models/quiz_level.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_set_policy.dart';

/// Bir turun/seviyenin KENDİ İÇİNDEKİ konu tekrarını ölçer (2026-10-02).
///
/// ## Kusur
///
/// "Edebiyat › Helbest › 1. Seviye" dokuz sorunun üçünde Cegerxwîn'i
/// soruyordu ve iki de neredeyse aynı kafiye ("qafiye") sorusu vardı. Her
/// soru tek başına doğruydu; tekrar soruların birbirine benzemesindeydi.
///
/// ## Niçin sessiz kalırdı
///
/// Var olan süzgeçler yalnız BİREBİR aynı metni (`dedupeByPrompt`), aynı
/// kelime çiftini (`dedupeByTranslationPair`) ve cevap sızıntısını
/// yakalıyordu; "aynı kişi hakkında üç ayrı soru" hiçbirine takılmıyordu.
/// Üstelik dilim tam boyda (9 soru / 9 aday) olduğundan tur seçimi yer
/// değiştirecek aday bulamıyordu: tekrar dilimin BİLEŞİMİNDE doğuyordu, bu
/// yüzden `_selectFresh` düzeltmesi tek başına yetmez. Seviye bekçileri de
/// boyut, ayrıklık ve konudaşlığa bakıyor, konu çeşitliliğine bakmıyordu.
///
/// ## Bu dosya ne ölçer
///
/// * Konu anahtarı: tırnaklı terim, baştaki özel ad, kısa/özel ad cevap.
/// * Benzer metin: belirteç Jaccard >= 0.6 (T/F kalıbı sayılmaz).
/// * Tur seçimi tekrarı atlar ama turu ASLA kısaltmaz.
/// * Seviye planı: tekrar komşu dilimle takasla giderilir; dilimler yine
///   ayrık, boyutlar aynı.
/// * Gerçek banka: Edebiyat › Helbest.
QuizQuestion _q(
  String id,
  String prompt,
  String answer, {
  int difficulty = 1,
  QuestionType type = QuestionType.multipleChoice,
}) => QuizQuestion(
  id: id,
  category: 'Edebiyat',
  prompt: prompt,
  answers: [answer, 'Alternatîf A $id', 'Alternatîf B $id', 'Alternatîf C $id'],
  correctAnswer: answer,
  explanation: '',
  difficulty: difficulty,
  type: type,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SeenQuestionStore.resetInstance();
  });

  group('konu anahtarı', () {
    test('tırnaklı terim, baştaki özel ad ve kısa cevap anahtar olur', () {
      expect(
        QuestionSetPolicy.subjectKey(
          _q('a', '"Cegerxwîn" kî bû?', 'Helbestvan'),
        ),
        'cegerxwîn',
      );
      expect(
        QuestionSetPolicy.subjectKey(
          _q('b', 'Cegerxwîn bi giştî çi bû?', 'Helbestvan'),
        ),
        'cegerxwîn',
      );
      expect(
        QuestionSetPolicy.subjectKey(
          _q('c', 'Elî Herîrî kî bû?', 'Helbestvanê klasîk ê soranî'),
        ),
        'elî herîrî',
      );
      expect(
        QuestionSetPolicy.subjectKey(
          _q('d', 'Ji lihevhatina dengên dawiyê re çi tê gotin?', 'Qafiye'),
        ),
        'kafiye',
      );
    });

    test('cümle başı sözcüğü, doğru/yanlış ve sayı konu sayılmaz', () {
      expect(
        QuestionSetPolicy.subjectKey(
          _q('e', 'Kîjan cure nivîsê hestan vedibêje bi dirêjî?', 'Rast'),
        ),
        isNull,
      );
      expect(
        QuestionSetPolicy.subjectKey(
          _q(
            'f',
            'Ev gotin rast e? Di wêjeya kevn de heye.',
            'Şaş',
            type: QuestionType.trueFalse,
          ),
        ),
        isNull,
      );
      expect(
        QuestionSetPolicy.subjectKey(
          _q('g', 'Kîjan sal ji bo vê bûyerê tê zanîn bi gelemperî?', '1946'),
        ),
        isNull,
      );
    });

    test('Rast e an şaş e kalıbı benzerliği şişirmez', () {
      expect(
        QuestionSetPolicy.promptSimilarity(
          'Rast e an şaş e: "Nalî" helbestvan e.',
          'Rast e an şaş e: "Mela Ehmed" li Cizîrê jiya.',
        ),
        lessThan(QuestionSetPolicy.similarPromptThreshold),
      );
      expect(
        QuestionSetPolicy.promptSimilarity(
          'Rast e an şaş e: "Ehmedê Xanî" ew helbestvan e ku Mewlûda Kurdî '
              'ya yekem nivîsiye.',
          'Rast e an şaş e: "Feqiyê Teyran" ew helbestvan e ku Mewlûda '
              'Kurdî ya yekem nivîsiye.',
        ),
        greaterThanOrEqualTo(QuestionSetPolicy.similarPromptThreshold),
      );
    });
  });

  group('tur seçimi', () {
    final cegerxwin = [
      _q('c1', '"Cegerxwîn" kî bû?', 'Helbestvanê civakî'),
      _q('c2', 'Cegerxwîn di helbesta kurdî de bi çi tê naskirin?', 'Şoreşger'),
      _q('c3', 'Cegerxwîn bi giştî çi bû?', 'Helbestvan'),
    ];
    final others = [
      _q('o1', 'Elî Herîrî kî bû?', 'Klasîkê soranî'),
      _q('o2', 'Nalî kî bû?', 'Dibistana Babanê'),
      _q('o3', 'Mela Ehmed li kîjan bajarî jiya?', 'Cizîr'),
    ];

    test('havuz yettiğinde bir konudan en çok bir soru gelir', () {
      final picked = QuestionSetPolicy.diverseWithoutLeaks([
        ...cegerxwin,
        ...others,
      ], limit: 4);
      expect(picked, hasLength(4));
      expect(
        picked.where((q) => QuestionSetPolicy.subjectKey(q) == 'cegerxwîn'),
        hasLength(1),
      );
    });

    test('havuz küçükse tur kısalmaz: tekrar son çare olarak girer', () {
      final picked = QuestionSetPolicy.diverseWithoutLeaks(cegerxwin, limit: 3);
      expect(picked.map((q) => q.id), ['c1', 'c2', 'c3']);
    });
  });

  group('seviye planı (sentetik)', () {
    test(
      'tekrar komşu dilimle takasla giderilir; dilimler ayrık, boy aynı',
      () {
        // 30 konudaş soru ("helbest" anahtar sözcüğü): dört Cegerxwîn sorusu
        // zorluk 1'de öbeklenmiş, yani bir dilimde dördü birden olurdu.
        const names = [
          'Nalî',
          'Salim',
          'Kurdî',
          'Mehwî',
          'Hêmin',
          'Goran',
          'Bêkes',
          'Şêrko',
          'Dilşa',
          'Evdal',
          'Perîxan',
          'Ronahî',
          'Bavê',
          'Zîlan',
          'Ferhad',
          'Hawar',
          'Mirza',
          'Delal',
          'Berfîn',
          'Kawa',
          'Rojda',
          'Avesta',
          'Baran',
          'Cîhan',
          'Dîlan',
          'Evîn',
        ];
        final pool = <QuizQuestion>[
          for (var i = 0; i < 4; i++)
            _q(
              'ceg$i',
              [
                '"Cegerxwîn" di helbestê de kî bû?',
                'Cegerxwîn di helbesta nûjen de bi çi tê naskirin?',
                'Cegerxwîn helbestvanê kîjan serdemê bû?',
                'Helbestên Cegerxwîn bi kîjan teşeyê hatine nivîsandin?',
              ][i],
              'Cevab ${i + 1} ji bo ceg',
              difficulty: 1,
            ),
          for (var i = 0; i < names.length; i++)
            _q(
              'n$i',
              'Helbestvan ${names[i]} li kîjan herêmê jiya û xebitî?',
              'Herêma ${names[i]}',
              difficulty: 1 + (i % 3),
            ),
        ];
        expect(
          pool.every((q) => SubcategoryConfig.getSubcategoryId(q) == 'helbest'),
          isTrue,
          reason: 'sentetik sorular helbest alt konusuna düşmeli',
        );
        const standard = [
          QuizLevel(
            number: 1,
            title: 'a',
            category: 'Edebiyat',
            difficultyMin: 1,
            difficultyMax: 2,
            questionCount: 6,
          ),
          QuizLevel(
            number: 2,
            title: 'b',
            category: 'Edebiyat',
            difficultyMin: 1,
            difficultyMax: 2,
            questionCount: 6,
          ),
          QuizLevel(
            number: 3,
            title: 'c',
            category: 'Edebiyat',
            difficultyMin: 2,
            difficultyMax: 3,
            questionCount: 6,
          ),
          QuizLevel(
            number: 4,
            title: 'd',
            category: 'Edebiyat',
            difficultyMin: 3,
            difficultyMax: 4,
            questionCount: 6,
          ),
          QuizLevel(
            number: 5,
            title: 'e',
            category: 'Edebiyat',
            difficultyMin: 4,
            difficultyMax: 5,
            questionCount: 6,
          ),
        ];
        final plan = SubcategoryLevelPlan.build(
          standardLevels: standard,
          categoryPool: pool,
          subCategory: 'helbest',
          seed: 1,
        );
        final all = <String>[];
        for (final level in plan.levels) {
          final cegerxwin = level.band.where(
            (q) => QuestionSetPolicy.subjectKey(q) == 'cegerxwîn',
          );
          expect(
            cegerxwin.length,
            lessThanOrEqualTo(1),
            reason: '${level.number}. seviyede Cegerxwîn tekrarı',
          );
          expect(
            level.band.length + level.fillers.length,
            greaterThanOrEqualTo(level.size),
          );
          all.addAll(level.band.map((q) => q.id));
        }
        expect(
          all.toSet().length,
          all.length,
          reason: 'dilimler ayrık kalmalı',
        );
        expect(all.length, pool.length, reason: 'hiçbir soru kaybolmamalı');
      },
    );
  });

  group('gerçek banka: Edebiyat › Helbest', () {
    test('hiçbir seviyede aynı konu 2 kez ya da benzer metin yok', () async {
      final repository = MockZanKurdRepository(levelSeed: 11);
      final levels = repository.levelsForCategory(
        'Edebiyat',
        subCategory: 'helbest',
      );
      expect(levels, hasLength(5));
      final report = StringBuffer();
      for (final level in levels) {
        final served = await repository.loadLevelQuestions(
          category: 'Edebiyat',
          difficultyMin: level.difficultyMin,
          difficultyMax: level.difficultyMax,
          subCategory: 'helbest',
          levelNumber: level.number,
          limit: level.questionCount,
        );
        // Seviye kısalmadı.
        expect(served, hasLength(level.questionCount));
        final keys = <String>{};
        for (var i = 0; i < served.length; i++) {
          final key = QuestionSetPolicy.subjectKey(served[i]);
          if (key != null && !keys.add(key)) {
            report.writeln('${level.number}. seviye: "$key" tekrarı');
          }
          for (var j = i + 1; j < served.length; j++) {
            if (QuestionSetPolicy.promptSimilarity(
                  served[i].prompt,
                  served[j].prompt,
                ) >=
                QuestionSetPolicy.similarPromptThreshold) {
              report.writeln(
                '${level.number}. seviye: benzer metin '
                '${served[i].id} ~ ${served[j].id}',
              );
            }
          }
        }
      }
      expect(report.toString(), isEmpty, reason: report.toString());
    });
  });
}
