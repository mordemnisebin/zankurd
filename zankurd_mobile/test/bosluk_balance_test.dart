/// Denge denetiminin bulduğu dört boşluk kapalı kalmalı: «boşluk» bankası +
/// sunucu göçü.
///
/// ## Kusurlar (2026-10-02 denge denetimi)
///
/// 1. **Cîhan zor katman.** Zorluk 4 = 12, zorluk 5 = 3 soru vardı; 5.
///    seviye tam 15 soruyla kalıyordu, oyuncu aynı sorulara tekrar tekrar
///    düşüyordu.
/// 2. **Paradigma (Bilim ve Düşünce) zorluk 5.** Oynanabilir yalnız 7 soru.
/// 3. **Siyaset alt konuları.** `SubcategoryConfig.visibleFor` bir alt konuyu
///    yalnız anahtar kelimeyle eşleşen oynanabilir soru sayısı >= 20 ise
///    gösterir. Siyaset › Dîroka Siyasî ve Siyaseta Nûjen için eşleşen soru
///    0'dı (Tevgerên Civakî 7); iki kart hiç görünmüyordu. Kullanıcıya hata
///    gösterilmez: kart yalnız yoktur.
/// 4. **Doğru/yanlış eğimi.** Çand, Dîrok, Cografya doğru/yanlış
///    sorularında doğru cevap %64–74 oranında "Rast" idi. Oyuncu konuyu değil
///    «hep Rast de» kuralını öğrenirdi.
///
/// ## Niçin sessiz kalırdı
///
/// Bu kusurların hiçbiri bir test kırmaz: eksik içerik hata üretmez, yalnız
/// ince bir katman ya da gizli bir kart bırakır. Soru emekliye ayrılır ya da
/// bir anahtar kelime daraltılırsa denge bir sürümde geri bozulurdu.
///
/// ## Neyi korur
///
/// * Cîhan d4 + d5 >= 30, Paradigma d5 >= 15 (ÜRETİM bankasıyla).
/// * Siyaset › Dîroka Siyasî ve Siyaseta Nûjen kendi sorularıyla eşiği
///   geçer; `visibleFor` ikisini de döner.
/// * Çand, Dîrok, Cografya doğru/yanlış sorularında "Rast" payı <= %60.
/// * Yeni 121 soru dosyada eksiksiz: iki dilli, kaynaklı (https), `approved`.
/// * Sunucu göçü (`2026-10-02_bosluk_sync.sql`) banka dosyasıyla birebir
///   aynı 121 istemi taşır, kategori oluşturmaz, `on conflict` ve sayı
///   doğrulaması vardır; `applied.md`de satırı durur.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

const _bank = 'assets/data/bosluk_2026_10_02_questions.json';
const _sql = 'supabase/2026-10-02_bosluk_sync.sql';
const _count = 121;

void main() {
  late MockZanKurdRepository repository;
  late List<QuizQuestion> playable;

  setUp(() {
    // Yükleyiciyi tetikle (test ortamında senkron dosya okuması).
    expect(QuestionBankLoader.instance.allQuestions.length, greaterThan(1000));
    repository = MockZanKurdRepository();
    playable = repository.playableQuestions.toList();
  });

  int count(bool Function(QuizQuestion q) test) => playable.where(test).length;

  test('Cîhan zorluk 4 + 5 en az 30 soru', () {
    final hard = count(
      (q) => q.category == 'Cîhan' && (q.difficulty == 4 || q.difficulty == 5),
    );
    expect(
      hard,
      greaterThanOrEqualTo(30),
      reason: 'Cîhan zor katman yalnız $hard soruya düştü (hedef >= 30)',
    );
    // Beşinci seviye tek başına da ince kalmamalı: önceki durum 3 soruydu.
    expect(
      count((q) => q.category == 'Cîhan' && q.difficulty == 5),
      greaterThanOrEqualTo(10),
    );
  });

  test('Paradigma zorluk 5 en az 15 soru', () {
    final hard = count((q) => q.category == 'Paradigma' && q.difficulty == 5);
    expect(
      hard,
      greaterThanOrEqualTo(15),
      reason: 'Paradigma zorluk 5 yalnız $hard soruya düştü (hedef >= 15)',
    );
  });

  test('Siyaset: Dîroka Siyasî ve Siyaseta Nûjen görünür', () {
    for (final id in const ['diroka_siyasi', 'siyaseta_nujen']) {
      final n = count(
        (q) =>
            q.category == 'Siyaset' &&
            SubcategoryConfig.getSubcategoryId(q) == id,
      );
      expect(
        n,
        greaterThanOrEqualTo(SubcategoryConfig.kMinSubcategoryQuestions),
        reason: 'Siyaset › $id yalnız $n oynanabilir soruyla kaldı',
      );
    }
    expect(
      SubcategoryConfig.visibleFor('Siyaset', playable).map((s) => s.id),
      containsAll(['diroka_siyasi', 'siyaseta_nujen']),
      reason: 'Siyaset alt konu kartlarından biri gizli kaldı',
    );
  });

  test('Siyaset yeni soruları kolay katmanda da var (d1-2 >= 10 her konu)', () {
    final bank = (jsonDecode(File(_bank).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    final byId = {for (final q in playable) q.id: q};
    final easy = <String, int>{};
    for (final raw in bank.where((r) => r['category'] == 'Siyaset')) {
      final q = byId[raw['id']];
      expect(q, isNotNull, reason: '${raw['id']} oynanabilir değil');
      final id = SubcategoryConfig.getSubcategoryId(q!);
      if (q.difficulty <= 2) easy[id] = (easy[id] ?? 0) + 1;
    }
    expect(easy['diroka_siyasi'] ?? 0, greaterThanOrEqualTo(10));
    expect(easy['siyaseta_nujen'] ?? 0, greaterThanOrEqualTo(10));
  });

  test('Çand, Dîrok, Cografya doğru/yanlışta "Rast" payı <= %60', () {
    for (final category in const ['Çand', 'Dîrok', 'Cografya']) {
      final tf = playable
          .where(
            (q) => q.category == category && q.type == QuestionType.trueFalse,
          )
          .toList();
      expect(tf, isNotEmpty, reason: '$category doğru/yanlış sorusu yok');
      final rast = tf.where((q) => q.correctAnswer == 'Rast').length;
      final share = rast / tf.length;
      expect(
        share,
        lessThanOrEqualTo(0.60),
        reason:
            '$category doğru/yanlış: $rast/${tf.length} (%${(share * 100).round()}) '
            '"Rast"; eğim geri geldi',
      );
    }
  });

  group('banka dosyası', () {
    late List<Map<String, dynamic>> bank;
    setUp(() {
      bank = (jsonDecode(File(_bank).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
    });

    test('$_count kayıt, kimlikler bosluk_NNNN ve benzersiz', () {
      expect(bank, hasLength(_count));
      final ids = bank.map((q) => q['id'] as String).toList();
      expect(ids.toSet(), hasLength(_count));
      for (var i = 0; i < ids.length; i++) {
        expect(ids[i], 'bosluk_${(i + 1).toString().padLeft(4, '0')}');
      }
    });

    test('hepsi iki dilli, kaynaklı ve onaylı', () {
      for (final q in bank) {
        final id = q['id'];
        final meta = q['metadata'] as Map<String, dynamic>;
        expect(meta['reviewStatus'], 'approved', reason: '$id');
        expect(
          meta['sourceReference'] as String,
          startsWith('https://'),
          reason: '$id kaynak adresi yok',
        );
        for (final f in const [
          'prompt',
          'promptTr',
          'correctAnswer',
          'correctAnswerTr',
          'explanationKu',
          'explanationTr',
        ]) {
          expect((q[f] as String).trim(), isNotEmpty, reason: '$id.$f boş');
        }
        final answers = (q['answers'] as List).cast<String>();
        final answersTr = (q['answersTr'] as List).cast<String>();
        expect(answersTr, hasLength(answers.length), reason: '$id');
        expect(answers, contains(q['correctAnswer']), reason: '$id');
        expect(answersTr, contains(q['correctAnswerTr']), reason: '$id');
        expect(
          answers.indexOf(q['correctAnswer'] as String),
          answersTr.indexOf(q['correctAnswerTr'] as String),
          reason: '$id Kurmancî ve Türkçe doğru şık aynı konumda değil',
        );
      }
    });

    test('doğru/yanlış sorular biçimi: 45 tane, hepsi Şaş cevaplı', () {
      final tf = bank.where((q) => q['type'] == 'trueFalse').toList();
      expect(tf, hasLength(45));
      for (final q in tf) {
        expect(q['answers'], ['Rast', 'Şaş'], reason: '${q['id']}');
        expect(q['answersTr'], ['Doğru', 'Yanlış'], reason: '${q['id']}');
        expect(q['correctAnswer'], 'Şaş', reason: '${q['id']}');
        expect(q['correctAnswerTr'], 'Yanlış', reason: '${q['id']}');
        expect(
          q['prompt'] as String,
          startsWith('Rast e an şaş e:'),
          reason: '${q['id']}',
        );
        expect(
          q['promptTr'] as String,
          startsWith('Doğru mu yanlış mı:'),
          reason: '${q['id']}',
        );
      }
      for (final category in const ['Çand', 'Dîrok', 'Cografya']) {
        expect(tf.where((q) => q['category'] == category), hasLength(15));
      }
    });

    test('grup sayıları: Cîhan 20, Paradigma 12, Siyaset 44', () {
      int n(bool Function(Map<String, dynamic> q) test) =>
          bank.where(test).length;
      expect(n((q) => q['category'] == 'Cîhan'), 20);
      expect(n((q) => q['category'] == 'Cîhan' && q['difficulty'] == 4), 12);
      expect(n((q) => q['category'] == 'Cîhan' && q['difficulty'] == 5), 8);
      expect(n((q) => q['category'] == 'Paradigma'), 12);
      expect(
        n((q) => q['category'] == 'Paradigma' && q['difficulty'] == 5),
        12,
      );
      expect(n((q) => q['category'] == 'Siyaset'), 44);
    });
  });

  group('sunucu göçü', () {
    late String sql;
    setUp(() => sql = File(_sql).readAsStringSync());

    test('göç = banka dosyasındaki $_count istem', () {
      final bank = (jsonDecode(File(_bank).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      final rows = RegExp(
        r"^\('([0-9a-f-]{36})', \(select id from categories where name = "
        r"'([^']+)'\), 'ku-kmr', '((?:[^']|'')*)', ",
        multiLine: true,
      ).allMatches(sql).toList();
      expect(rows, hasLength(bank.length));
      expect(
        {for (final m in rows) '${m.group(2)}|${m.group(3)}'},
        {
          for (final q in bank)
            '${q['category']}|${(q['prompt'] as String).replaceAll("'", "''")}',
        },
        reason: 'banka değişti, tool/sync_bosluk_to_server.py yeniden koşmalı',
      );
      expect(rows.map((m) => m.group(1)).toSet(), hasLength(rows.length));
    });

    test('ekleme güvenli: çakışmada atlar, kategori oluşturmaz, sayar', () {
      final code = sql
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('--'))
          .join('\n');
      expect(code, contains('on conflict (id) do nothing'));
      expect(code, isNot(contains('insert into categories')));
      expect(code.toLowerCase(), isNot(contains('delete ')));
      expect(code, contains('Eksik kategori'));
      expect(code, contains('<> $_count'));
      expect(code.trimRight(), endsWith('commit;'));
    });

    test('applied.md satırı var', () {
      expect(
        File('supabase/applied.md').readAsStringSync(),
        contains('2026-10-02_bosluk_sync.sql'),
      );
    });
  });
}
