/// «Cîhan / Dünya» kategorisinin ve çok modelli doğrulanmış içeriğin bekçisi.
///
/// ## Kusur
///
/// Ürün ~%70 Kürt içeriği + ~%30 nötr genel bilgi olacak (2026-09-30 ürün
/// sahibi kararı). Genel bilgi, Kürt kategorilerinin içine karışırsa oyuncu
/// hangi sorunun neyi ölçtüğünü bilemez; bu yüzden ayrı ve adı açık bir
/// kategoride durur. Bir kategorinin «görünür» olması için birden çok yerin
/// (ad, ton, silüet, alt konu, ana sayfa listesi, soru) birlikte doğru
/// olması gerekir; biri unutulursa kategori ya hiç görünmez ya boş görünür
/// ya da silüetsiz/adsız kalır — hata vermeden.
///
/// İkinci kusur: DeepSeek dalgası (1110 kayıt) olgu hatası yüzünden
/// karantinadaydı. Doğrulanan 458'i ayrı bir dosyaya KOPYALANDI; orijinal
/// dosya listede YOK kalmalı. Biri orijinali listeye sokarsa karantinadaki
/// ~650 doğrulanmamış soru sessizce oyuncuya ulaşır.
///
/// ## Neyi korur
///
/// * Cîhan görünür, TR «Dünya» / KU «Cîhan», silüeti ve tonu var, ana
///   sayfada Kürt kategorilerinden sonra gelir, üç alt konusu da görünür
///   (her biri ≥ 20 soru).
/// * Oynanabilir Cîhan sorusu ≥ 20 (bugün 166) ve hiçbiri emekli değil.
/// * Doğrulanmış DeepSeek dosyası kayıtlı, orijinal kayıtsız; kayıtlı dosya
///   orijinalin birebir kopyası (metin değişmemiş), hepsi `approved` ve
///   künyeli; orijinalin DOĞRULANMAMIŞ hiçbir kaydı yüklenmiyor.
/// * 70 bilim sorusu Paradigma'da, kaynaklı, doğru şık konumları dengeli.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visibility.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/config/retired_question_ids.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne_topic_marks.dart';

const _verified = 'assets/data/deepseek_verified_2026_09_30_questions.json';
const _quarantined = 'assets/data/deepseek_2026_08_18_questions.json';
const _science = 'assets/data/bilim_2026_09_30_questions.json';

List<Map<String, dynamic>> _read(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

void main() {
  const policy = QuestionContentPolicy();
  final repository = MockZanKurdRepository();

  group('kategori', () {
    test('Cîhan görünür ve ana sayfada Kürt kategorilerinden sonra gelir', () {
      expect(isCategoryVisible('Cîhan'), isTrue);
      final categories = repository.categories;
      expect(categories, contains('Cîhan'));
      expect(categories.last, 'Cîhan');
      for (final kurdish in ['Ziman', 'Çand', 'Dîrok', 'Edebiyat', 'Muzîk']) {
        expect(
          categories.indexOf(kurdish),
          lessThan(categories.indexOf('Cîhan')),
          reason: '$kurdish Cîhan\'dan önce gelmeli',
        );
      }
    });

    test('adı TR «Dünya», KU «Cîhan»; takma adlar kimliğe çözülür', () {
      expect(CategoryNames.localized('Cîhan', false), 'Dünya');
      expect(CategoryNames.localized('Cîhan', true), 'Cîhan');
      expect(CategoryNames.tr('Cîhan'), 'Dünya');
      expect(CategoryVisuals.canonicalName('Dünya'), 'Cîhan');
      expect(CategoryVisuals.canonicalName('Cihan'), 'Cîhan');
    });

    test('silüeti ve kendi tonu var; ad tonun üstünde okunur', () {
      expect(CategoryVisuals.mark('Cîhan'), SahneTopicMark.cihan);
      expect(CategoryVisuals.tone('Cîhan'), SahneCategoryTone.cihan);
      expect(
        SahneCategoryTone.cihan,
        isNot(SahneCategoryTone.fallback),
        reason: 'Cîhan sahne gecesi yedeğine düşmemeli',
      );
      final a = SahneCategoryTone.cihan.ground.computeLuminance();
      final b = SahneTokens.night.tx.computeLuminance();
      expect((b + 0.05) / (a + 0.05), greaterThanOrEqualTo(4.5));
      // Ödünç görsel yanlış konuyu anlatır: kendi fotoğrafı yok.
      expect(CategoryVisuals.ownImagePath('Cîhan'), isNull);
    });
  });

  group('içerik', () {
    late List<dynamic> playable;

    setUpAll(() {
      playable = QuestionBankLoader.instance.allQuestions
          .where(policy.isPlayable)
          .where((q) => q.category == 'Cîhan')
          .toList();
    });

    test('en az 20 oynanabilir Cîhan sorusu var, hiçbiri emekli değil', () {
      expect(playable.length, greaterThanOrEqualTo(20));
      for (final q in playable) {
        expect(isQuestionRetired(q.id as String), isFalse, reason: '${q.id}');
      }
    });

    test('üç alt konunun üçü de görünür (her biri en az 20 soru)', () {
      final visible = SubcategoryConfig.visibleFor(
        'Cîhan',
        QuestionBankLoader.instance.allQuestions.where(policy.isPlayable),
      );
      expect(visible.map((s) => s.id), [
        'sinema_cihan',
        'erdnigari_cihan',
        'dirok_gisti',
      ]);
    });

    test('Kürt diliyle ilgili sözcük soruları Cîhan\'a girmedi', () {
      // «Kêr», «Metbex», «Newroz» gibi Kurmancî/Kürt kültürü soruları
      // DeepSeek'te «genel bilgi» diye işaretliydi ama kendi kategorisinde
      // kalır: Kurmancî sözcük öğreten soruyu «Dünya» altında göstermek
      // kategori adını yalan yapar.
      final cihanIds = {for (final q in playable) q.id as String};
      for (final id in ['ds_ziman_1102', 'ds_cand_0006', 'ds_cand_0011']) {
        expect(cihanIds, isNot(contains(id)), reason: id);
      }
    });
  });

  group('DeepSeek karantinası', () {
    test('doğrulanmış dosya kayıtlı, orijinal karantinada kalır', () {
      expect(questionBankAssets, contains(_verified));
      expect(
        questionBankAssets,
        isNot(contains(_quarantined)),
        reason:
            'Orijinal DeepSeek dosyası ~%5–8 olgu hatası yüzünden '
            'karantinada; listeye girerse doğrulanmamış soru oyuncuya ulaşır',
      );
    });

    test(
      'kopya orijinale sadık: Türkçe değişmemiş, doğru konum korunmuş, künyeli',
      () {
        final original = {for (final q in _read(_quarantined)) q['id']: q};
        final copies = _read(_verified);
        // 458 (dalga 1) + 364 (dalga 2) + 31 (dalga 3) = 853; ChatGPT'nin
        // kaynak taramasında 44 kayıt (30 kaynak yok, 14 cevap yanlış)
        // karantinaya döndü: 853 - 44 = 809.
        expect(copies.length, 809);
        // 2026-10-02: TEK editoryal düzeltme. `ds_cografya_0177`nin çeldiricisi
        // "Dirêjahî û firehî" ("Uzunluk ve genişlik") enlem/boylam için de
        // geçerli bir Kurmancî ifadeydi: iki doğru şık. "Dem û lez" ("Zaman ve
        // hız") ile değişti; şıkkın iki dildeki karşılığı birlikte değişir,
        // doğru şıkkın konumu aynı kalır. Sunucu göçü:
        // supabase/2026-10-02_e2e_content_fixes.sql. Başka kayıt bu listeye
        // bilinçli bir kararla eklenir.
        const editorialFixes = <String, Set<String>>{
          'ds_cografya_0177': {'answers', 'answersTr'},
        };
        for (final c in copies) {
          final o = original[c['id']];
          expect(o, isNotNull, reason: '${c['id']} orijinalde yok');
          // Türkçe alanlar, zorluk ve tür hiçbir dalgada değişmez.
          for (final key in [
            'promptTr',
            'answersTr',
            'correctAnswerTr',
            'explanationTr',
            'difficulty',
            'type',
          ]) {
            if (editorialFixes[c['id']]?.contains(key) ?? false) continue;
            expect(c[key], o![key], reason: '${c['id']}.$key değişmiş');
          }
          // Kurmancî metin yalnız ikinci ve üçüncü dalgada (Gemini 3.1 Pro düzeltmesi,
          // Grok/Flash onayı) değişebilir; dalga-1 kayıtları birebir aynı.
          final meta = c['metadata'] as Map<String, dynamic>;
          final reviewedBy = meta['reviewedBy'] as String;
          final corrected =
              reviewedBy.contains('ikinci dalga') ||
              reviewedBy.contains('üçüncü dalga');
          if (!corrected) {
            for (final key in [
              'prompt',
              'answers',
              'correctAnswer',
              'explanationKu',
              'explanation',
            ]) {
              if (editorialFixes[c['id']]?.contains(key) ?? false) continue;
              expect(c[key], o![key], reason: '${c['id']}.$key değişmiş');
            }
          } else if (c['explanation'] != o!['explanation']) {
            // Bazı DeepSeek kayıtlarında `explanation` Türkçe değil Kurmancî
            // açıklamanın kopyasıdır; düzeltme ikisine birlikte uygulanır.
            expect(o['explanation'], o['explanationKu'], reason: '${c['id']}');
            expect(c['explanation'], c['explanationKu'], reason: '${c['id']}');
          }
          // Hangi şıkkın doğru olduğu (konum) hiçbir düzeltmeyle değişmez.
          final oldAnswers = (o!['answers'] as List).cast<String>();
          final newAnswers = (c['answers'] as List).cast<String>();
          expect(
            newAnswers.indexOf(c['correctAnswer'] as String),
            oldAnswers.indexOf(o['correctAnswer'] as String),
            reason: '${c['id']}: doğru şıkkın konumu değişmiş',
          );
          if (editorialFixes.containsKey(c['id'])) {
            // Düzeltilen şık iki dilde de aynı konumda değişmiş olmalı.
            final tr = (c['answersTr'] as List).cast<String>();
            expect(tr.length, newAnswers.length);
            expect(
              tr.indexOf(c['correctAnswerTr'] as String),
              newAnswers.indexOf(c['correctAnswer'] as String),
              reason: '${c['id']}: iki dildeki doğru konum ayrışmış',
            );
          }
          expect(newAnswers.length, oldAnswers.length);
          expect(newAnswers.toSet().length, newAnswers.length);
          expect(meta['reviewStatus'], 'approved', reason: '${c['id']}');
          expect(meta['reviewedBy'], isA<String>(), reason: '${c['id']}');
          expect(meta['reviewedAt'], '2026-09-30', reason: '${c['id']}');
          // Kategori yalnız «genel bilgi» → Cîhan yönünde değişebilir.
          if (c['category'] != o['category']) {
            expect(c['category'], 'Cîhan', reason: '${c['id']}');
          }
        }
      },
    );

    test('orijinalin doğrulanmamış hiçbir kaydı yüklenmiyor', () {
      final verifiedIds = {for (final q in _read(_verified)) q['id']};
      final loaded = {
        for (final q in QuestionBankLoader.instance.allQuestions) q.id,
      };
      final leaked = [
        for (final q in _read(_quarantined))
          if (!verifiedIds.contains(q['id']) && loaded.contains(q['id']))
            q['id'],
      ];
      expect(leaked, isEmpty, reason: 'Karantinadan sızan: $leaked');
    });
  });

  group('bilim soruları (Paradigma)', () {
    test('70 kaynaklı soru Paradigma\'da, doğru şık konumları dengeli', () {
      final rows = _read(_science);
      // 40 (ilk dalga) + 30 (bilim_0041…0070, aynı gün).
      expect(rows.length, 70);
      expect(questionBankAssets, contains(_science));
      final positions = <int, int>{};
      for (final q in rows) {
        expect(q['category'], 'Paradigma');
        expect(q['id'], startsWith('bilim_'));
        final meta = q['metadata'] as Map<String, dynamic>;
        expect(
          meta['sourceReference'],
          startsWith('https://'),
          reason: '${q['id']} kaynaksız',
        );
        expect(meta['reviewStatus'], 'approved');
        final answers = (q['answers'] as List).cast<String>();
        final answersTr = (q['answersTr'] as List).cast<String>();
        final i = answers.indexOf(q['correctAnswer'] as String);
        expect(i, isNonNegative, reason: '${q['id']}');
        expect(answersTr.indexOf(q['correctAnswerTr'] as String), i);
        // Oyuncunun GÖRDÜĞÜ konum (`displayAnswers`: id'den türeyen kaydırma).
        final shown = QuizQuestion.fromJson(
          q,
        ).displayAnswers.indexOf(q['correctAnswer'] as String);
        positions[shown] = (positions[shown] ?? 0) + 1;
      }
      // Kaynak JSONL'de doğru şık 40'ın 38'inde ilk şıktaydı. Görünen
      // konumlar dört yana dağılmalı (bütün bankanın dengesini
      // `question_bank_test` ölçer). 70 soruda ideal 17-18.
      for (final p in [0, 1, 2, 3]) {
        expect(positions[p], inInclusiveRange(12, 23), reason: 'konum $p');
      }
    });

    test('hepsi oynanabilir ve Paradigma sayısı 42\'den büyüdü', () {
      final playable = QuestionBankLoader.instance.allQuestions
          .where(policy.isPlayable)
          .where((q) => q.category == 'Paradigma')
          .toList();
      expect(playable.where((q) => q.id.startsWith('bilim_')).length, 70);
      expect(playable.length, greaterThanOrEqualTo(110));
    });
  });

  test('gizli kategori listesi boş kalır', () {
    expect(hiddenCategoryIds, isEmpty);
  });
}
