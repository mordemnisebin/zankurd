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
          // 2026-10-23 soru kalitesi taraması: Flash + Grok tarama, GPT-5.6 +
          // Claude Opus 5 doğrulama (uyuşmazlıkta Grok hakem). Doğru şıkkın
          // kimliği ve iki dildeki hizası korunur.
          'ds_edebiyat_0157': {
            'answers',
            'correctAnswer',
            'answersTr',
            'correctAnswerTr',
          },
          'ds_teknoloji_0130': {'answers', 'correctAnswer'},
          'ds_cand_0033': {
            'explanation',
            'explanationTr',
            'prompt',
            'promptTr',
          },
          'ds_cand_0035': {
            'explanation',
            'explanationTr',
            'prompt',
            'promptTr',
          },
          'ds_cand_0159': {'answersTr'},
          'ds_dirok_0010': {'prompt', 'promptTr'},
          'ds_dirok_0016': {'prompt', 'promptTr'},
          'ds_dirok_0173': {'prompt', 'promptTr'},
          'ds_dirok_0287': {'answers'},
          'ds_dirok_0293': {'prompt', 'promptTr'},
          'ds_edebiyat_0102': {'answers', 'answersTr'},
          'ds_edebiyat_0106': {'answers'},
          'ds_edebiyat_0108': {'answers'},
          'ds_edebiyat_0110': {'answers'},
          'ds_edebiyat_0112': {'answers'},
          'ds_edebiyat_0114': {'answers'},
          'ds_edebiyat_0122': {'answers'},
          'ds_edebiyat_0124': {'answers'},
          'ds_muzik_0023': {'prompt', 'promptTr'},
          'ds_muzik_0103': {'prompt'},
          'ds_muzik_0203': {'answersTr', 'correctAnswerTr'},
          'ds_sinema_0194': {'prompt', 'promptTr'},
          'ds_sinema_0249': {'promptTr'},
          'ds_sinema_0286': {'prompt'},
          'ds_teknoloji_0010': {'answers'},
          'ds_teknoloji_0073': {'prompt', 'promptTr'},
          'ds_teknoloji_0195': {'answers'},
          'ds_teknoloji_0197': {'answers'},
          // 2026-10-24 yazım taraması: «Kurmanci/Kurmancça/Kurmancicede» →
          // «Kurmancî/Kurmancîde» (id, alan) çiftlerine tek tek; doğru şıkkın
          // kimliği korunur. Sunucu göçü: supabase/2026-10-24_icerik_yazim.sql.
          'ds_cand_0041': {'explanation', 'explanationKu', 'explanationTr'},
          'ds_dirok_0128': {'answersTr', 'correctAnswerTr'},
          'ds_muzik_0008': {
            'answersTr',
            'correctAnswerTr',
            'explanation',
            'explanationTr',
          },
          'ds_muzik_0249': {'answers', 'correctAnswer'},
          'ds_ziman_0007': {'promptTr'},
          'ds_ziman_0011': {'promptTr'},
          'ds_ziman_0018': {'explanation', 'explanationTr'},
          'ds_ziman_0025': {'promptTr'},
          'ds_ziman_0027': {'promptTr'},
          'ds_ziman_0028': {'explanation', 'explanationTr'},
          'ds_ziman_0029': {'promptTr'},
          'ds_ziman_0030': {'promptTr'},
          'ds_ziman_0032': {'promptTr'},
          'ds_ziman_0035': {'promptTr'},
          'ds_ziman_0039': {'promptTr'},
          'ds_ziman_0044': {'promptTr'},
          'ds_ziman_0052': {'explanation', 'explanationTr', 'promptTr'},
          'ds_ziman_0206': {'explanation', 'explanationTr', 'promptTr'},
          'ds_ziman_0256': {'explanation', 'explanationTr', 'promptTr'},
          'ds_ziman_0257': {'explanation', 'explanationTr', 'promptTr'},
          'ds_ziman_0266': {'explanation', 'explanationTr', 'promptTr'},
          'ds_ziman_0272': {'explanation', 'explanationTr', 'promptTr'},
          'ds_ziman_0278': {'promptTr'},
          'ds_ziman_0292': {'explanation', 'explanationTr', 'promptTr'},
          'ds_ziman_1028': {'promptTr'},
          'ds_ziman_1029': {'promptTr'},
          'ds_ziman_1031': {'promptTr'},
          'ds_ziman_1034': {'promptTr'},
          'ds_ziman_1036': {'promptTr'},
          'ds_ziman_1038': {'promptTr'},
          // 2026-10-29 Opus 5.5 + GPT-6 Astra kapışması (U7): izolin tanımı,
          // belirsiz kökler (iç göç, geri yayılım, forwarding) ve aynı türden
          // şıklar. Doğru şıkkın konumu ve iki dildeki hizası korunur.
          'ds_cografya_0199': {'explanation', 'explanationTr'},
          'ds_cografya_0205': {'explanation', 'explanationTr', 'promptTr'},
          'ds_teknoloji_0136': {'promptTr', 'answersTr'},
          'ds_teknoloji_0328': {'promptTr', 'answersTr', 'correctAnswerTr'},
        };
        for (final c in copies) {
          final o = original[c['id']];
          if (o == null) fail('${c['id']} orijinalde yok');
          // Türkçe alanlar, zorluk ve tür hiçbir dalgada değişmez.
          //
          // 2026-10-02: ŞIK SIRASI hariç. `rebalance_answer_positions.py`
          // doğru cevabın konumunu kategori başına dengeler ve kopyayı
          // karantinadaki orijinalden bağımsız olarak yeniden sıralar; bu
          // yüzden şıklar SIRALANMIŞ karşılaştırılır (aynı şık kümesi) ve
          // doğru cevabın kimliği (Kurmancî ↔ Türkçe hizası) ayrıca
          // doğrulanır — eskiden "konum aynı" diye bakılan şey buydu.
          for (final key in [
            'promptTr',
            'correctAnswerTr',
            'explanationTr',
            'difficulty',
            'type',
          ]) {
            if (editorialFixes[c['id']]?.contains(key) ?? false) continue;
            expect(c[key], o[key], reason: '${c['id']}.$key değişmiş');
          }
          List<String> sorted(Object? list) =>
              (list as List).cast<String>().toList()..sort();
          if (!(editorialFixes[c['id']]?.contains('answersTr') ?? false)) {
            expect(
              sorted(c['answersTr']),
              sorted(o['answersTr']),
              reason: '${c['id']}.answersTr kümesi değişmiş',
            );
          }
          // Kurmancî metin yalnız ikinci ve üçüncü dalgada (Gemini 3.1 Pro düzeltmesi,
          // Grok/Flash onayı) değişebilir; dalga-1 kayıtları birebir aynı.
          final meta = c['metadata'] as Map<String, dynamic>;
          final reviewedBy = meta['reviewedBy'] as String;
          // 2026-10-15: dördüncü dalga, bütün bankaların Kurmancî denetimi
          // (Gemini 3.8 Flash + Grok 4.7, ana ajan vetosu); künyesi kayıtta.
          final corrected =
              reviewedBy.contains('ikinci dalga') ||
              reviewedBy.contains('üçüncü dalga') ||
              reviewedBy.contains('dördüncü dalga');
          if (!corrected) {
            for (final key in [
              'prompt',
              'correctAnswer',
              'explanationKu',
              'explanation',
            ]) {
              if (editorialFixes[c['id']]?.contains(key) ?? false) continue;
              expect(c[key], o[key], reason: '${c['id']}.$key değişmiş');
            }
            if (!(editorialFixes[c['id']]?.contains('answers') ?? false)) {
              expect(
                sorted(c['answers']),
                sorted(o['answers']),
                reason: '${c['id']}.answers kümesi değişmiş',
              );
            }
          } else if (c['explanation'] != o['explanation'] &&
              !(editorialFixes[c['id']]?.contains('explanation') ?? false)) {
            // (2026-10-24: `explanation`ı Türkçe olan kayıtların yazım
            // düzeltmesi `editorialFixes`te açıkça bildirilir.)
            // Bazı DeepSeek kayıtlarında `explanation` Türkçe değil Kurmancî
            // açıklamanın kopyasıdır; düzeltme ikisine birlikte uygulanır.
            expect(o['explanation'], o['explanationKu'], reason: '${c['id']}');
            expect(c['explanation'], c['explanationKu'], reason: '${c['id']}');
          }
          // Doğru şıkkın KİMLİĞİ hiçbir düzeltmeyle değişmez: Kurmancî ve
          // Türkçe doğru cevap aynı konumda durur (hiza) ve Türkçe doğru
          // cevap orijinaliyle aynı kalır.
          final oldAnswers = (o['answers'] as List).cast<String>();
          final newAnswers = (c['answers'] as List).cast<String>();
          expect(
            newAnswers.indexOf(c['correctAnswer'] as String),
            (c['answersTr'] as List).indexOf(c['correctAnswerTr']),
            reason: '${c['id']}: Kurmancî ve Türkçe doğru şık hizalı değil',
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
