import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'support/offline_bank_fixture.dart';

String _normalized(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

late List<QuizQuestion> offlineQuestionBank;

void main() {
  // Liste elle kopyalanmıştı ve kaydı: Sînema açılınca (2026-07-30) banka
  // geçerli bir kategori taşıyordu ama test onu "unknown" saydı. Kaynak
  // artık görsel tanımlarıdır — rengi, ikonu ve görseli olmayan bir
  // kategoriye soru yazmak zaten kusurdur, test tam onu ölçsün.
  final validCategories = CategoryVisuals.colorDefinedCategories.toSet();

  setUpAll(() {
    offlineQuestionBank = loadOfflineBankFromJson();
  });

  test('all question ids are unique', () {
    final ids = offlineQuestionBank.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('normalized prompts are unique within each category', () {
    final keys = offlineQuestionBank
        .map((q) => '${q.category}|${_normalized(q.prompt)}')
        .toList();

    expect(keys.toSet().length, keys.length);
  });

  // Kuralın koruduğu şey: hiçbir şey bilmeyen oyuncu "hep C'yi seç" diyerek
  // puan kazanamamalı.
  //
  // Bu ölçüt içerik değiştikçe kendiliğinden bozulur — 2026-07-30'da 290
  // kopya soru atılınca dağılım [207, 212, 194, 200] oldu. Bozulunca eşiği
  // gevşetmek yanlış refleks: bankayı yeniden dengeleyen araç zaten var.
  //
  //     python3 tool/rebalance_answer_positions.py offline_curated
  //
  // Araç *depolanan* şık sırasını oynatır; görünen sıra id'den türeyen sabit
  // bir kaydırmayla hesaplandığı için dengeleme görünen sıraya göre yapılır.
  // Yeni soru ekledikten sonra çalıştırın, sonra bu test yeşile döner.
  // 2026-08-01: bu bekçi ve `rebalance_answer_positions.py` YALNIZ offline
  // bankasına bakıyordu; uygulama ise dört banka yüklüyor. Ölçüm:
  //
  //     offline    [221, 221, 221, 221]   yayılım   0  ← kapsamdaydı
  //     editorial  [  5,  76,  70, 130]   yayılım 125  ← kapsam dışı
  //     community  [  0,  11,  12,  23]   yayılım  23  ← kapsam dışı
  //
  // Editoryal sorularda hep D'ye basan oyuncu %46 doğru yapıyordu;
  // topluluk sorularında A hiçbir zaman doğru değildi. Koruma vardı,
  // kapsamı eksikti. Ölçüm artık `questionBankAssets`teki her bankayı
  // kapsıyor — araç da öyle.
  // 2026-10-02: bu bekçi YALNIZ küresel yayılıma bakar; kategori başına denge
  // (oynanabilir sorularda her konum %25 ± 5) ve doğru/yanlış şık sırası
  // `answer_position_category_balance_test.dart`ta. Araç artık
  // `--playable .tmp/parity/local_bank.json` ile oynanabilir kümeyi de
  // kategori başına dengeler (bkz. `tool/rebalance_answer_positions.py`).
  //
  // 2026-11-15: `yeni2_2026_11_10_questions.json` (696 soru) CANLI sunucuda.
  // Sunucudaki option_a..d ve correct_option bu dosyadaki şık sırasından
  // üretildi; dengelemek için sırayı yerelde değiştirmek yerel ile canlıyı aynı
  // soruda ayrıştırırdı (correct_option başka metni gösterirdi). Bu yüzden o
  // bankanın saklanan sırası DONDURULDU ve araçla dengelenmez. Ölçüm:
  //
  //     bütün bankalar  [971, 979, 963, 958]  yayılım 21
  //     yeni2 hariç     [794, 794, 793, 794]  yayılım  1  ← katı kural burada
  //     yeni2 (696)     [177, 185, 170, 164]  yayılım 21  (%3; saklanan
  //                                                       [174, 183, 174, 165])
  //
  // Bu metrik oyuncunun gördüğü sırayı değil, tura bağlanmamış eski görünümü
  // (id'den türeyen sabit kaydırma) ölçer; oyun ekranları tura bağlı karıştırma
  // kullanır, yani 21'lik fark oyunda doğru cevabı tahmin ettirmez. Kural:
  // yeni2 dışındaki bankalarda yayılım ≤ 1 (eski sıkılık aynen), yeni2'de bankanın
  // %5'i.
  test('displayed correct-answer positions are balanced', () {
    final frozen = <int>[0, 0, 0, 0];
    final counts = List<int>.filled(4, 0);
    var frozenSize = 0;
    final all = <QuizQuestion>[];
    final isFrozen = <bool>[];
    for (final asset in questionBankAssets) {
      if (!File(asset).existsSync()) continue;
      final rows = (jsonDecode(File(asset).readAsStringSync()) as List).map(
        (e) => QuizQuestion.fromJson(e as Map<String, dynamic>),
      );
      for (final question in rows) {
        all.add(question);
        isFrozen.add(asset.endsWith('yeni2_2026_11_10_questions.json'));
      }
    }
    expect(
      all.length,
      greaterThan(1000),
      reason: 'Bekçi kör kalmasın: bankalar yüklenemediyse yayılım 0 çıkar.',
    );
    for (var i = 0; i < all.length; i++) {
      final question = all[i];
      if (question.answers.length != 4 ||
          !question.answers.contains(question.correctAnswer)) {
        continue;
      }
      final position = question.displayAnswers.indexOf(question.correctAnswer);
      if (isFrozen[i]) {
        frozen[position]++;
        frozenSize++;
      } else {
        counts[position]++;
      }
    }

    int spreadOf(List<int> values) =>
        values.reduce((a, b) => a > b ? a : b) -
        values.reduce((a, b) => a < b ? a : b);

    expect(
      frozenSize,
      greaterThan(0),
      reason: 'Dondurulmuş banka yüklenmediyse bu ayrım kör kalır.',
    );
    expect(
      spreadOf(counts),
      lessThanOrEqualTo(1),
      reason:
          'Dağılım (yeni2 hariç): $counts — dengelemek için '
          '`python3 tool/rebalance_answer_positions.py offline_curated`',
    );
    expect(
      spreadOf(frozen),
      lessThanOrEqualTo((frozenSize * 0.05).floor()),
      reason:
          'yeni2 dağılımı: $frozen. Canlıda olan banka; şık sırasını '
          'değiştirmek correct_option ile yerel kopyayı ayrıştırır.',
    );
  });

  test('every correct answer exists among its options', () {
    for (final question in offlineQuestionBank) {
      expect(
        question.answers,
        contains(question.correctAnswer),
        reason: '${question.id}: correctAnswer not in answers',
      );
    }
  });

  // Kapsam 2026-08-01'de `offlineQuestionBank`ten bütün bankalara
  // genişletildi. Editoryal ve topluluk bankaları hiç taranmıyordu —
  // aynı gece bulunan "koruma var, kapsamı eksik" deseninin bir örneği
  // daha.
  //
  // Eşik (6 karakter) yerinde bırakıldı: kısa cevaplarda soru metniyle
  // rastlantısal örtüşme yanlış pozitif üretiyor. Bilinen tek istisna
  // `edit_edebiyat_0020` ("Melayê Cizîrî li kîjan bajarî jiya?" → Cizîr):
  // şairin mahlası şehrin adını taşıyor, yani sızıntı gerçek ama cevap
  // 5 karakter olduğu için eşiğin altında kalıyor. Soruyu yeniden
  // yazmak editör kararı; eşiği düşürmek yanlış refleks olurdu.
  test('prompts do not leak the correct answer text', () {
    final offenders = <String>[];
    final all = [
      for (final asset in questionBankAssets)
        if (File(asset).existsSync())
          ...(jsonDecode(File(asset).readAsStringSync()) as List).map(
            (e) => QuizQuestion.fromJson(e as Map<String, dynamic>),
          ),
    ];
    expect(all.length, greaterThan(1000));
    for (final question in all) {
      final correct = _normalized(question.correctAnswer);
      if (correct.length < 6) continue;

      final prompt = _normalized(question.prompt);
      if (prompt.contains(correct)) {
        offenders.add('${question.id}: ${question.correctAnswer}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Soru metni cevabı açıkça göstermemeli: $offenders',
    );
  });

  test('every question uses a known category', () {
    for (final question in offlineQuestionBank) {
      expect(
        validCategories,
        contains(question.category),
        reason: '${question.id}: unknown category ${question.category}',
      );
    }
  });

  test('difficulties stay within 1-5', () {
    for (final question in offlineQuestionBank) {
      expect(
        question.difficulty,
        inInclusiveRange(1, 5),
        reason: '${question.id}: difficulty ${question.difficulty}',
      );
    }
  });

  test('answer options are unique per question', () {
    for (final question in offlineQuestionBank) {
      expect(
        question.answers.toSet().length,
        question.answers.length,
        reason: '${question.id}: duplicate options',
      );
    }
  });

  test('true/false questions use Rast/Şaş options', () {
    for (final question in offlineQuestionBank.where(
      (q) => q.type == QuestionType.trueFalse,
    )) {
      expect(question.answers, [
        'Rast',
        'Şaş',
      ], reason: '${question.id}: unexpected true/false options');
    }
  });

  test('bank grew past 1100 questions', () {
    expect(offlineQuestionBank.length, greaterThan(1100));
  });

  test('prompts carry no difficulty-tier prefix labels', () {
    const prefixes = ['Temel:', 'Pekiştirme:', 'Ustalık:'];
    final offenders = <String>[];
    for (final question in offlineQuestionBank) {
      final p = question.prompt.trimLeft();
      for (final prefix in prefixes) {
        if (p.startsWith(prefix)) {
          offenders.add('${question.id}: $p');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Oyuncuya gösterilen prompt teknik önek taşımamalı: $offenders',
    );
  });

  // Bir seviyenin zorluk bandı içinde aynı prompt'un birden çok zorluk
  // kopyası tek quizde tekrar olarak çıkmasın diye seçim prompt'a göre
  // tekilleştiriyor (SeenQuestionStore.preferUnseen). Her bandın
  // prompt-bazında yeterli benzersiz sorusu olmalı.
  // Tam 5 seviyelik merdiven (Destpêk..Mamoste) yalnızca, en kolay seviyeyi
  // (zorluk 1, 10 soru) de doldurabilen "olgun" kategoriler için zorunludur.
  // Paradigma/Siyaset gibi ileri-kavramsal kategoriler bilinçli olarak
  // çoğunlukla orta-zor sorulardan oluşur (kullanıcının "az kolay soru"
  // tercihi); bunlara 10 yapay-kolay soru eklemek yerine tam-merdiven
  // testinden muaf tutulurlar. (Bu kategorilerin kolay seviyesi gerektiğinde
  // soruları döndürerek doldurur; preferUnseen tekrarları azaltır.)
  const ladderMaturityThreshold = 59; // 10+10+12+12+15
  bool isMature(String category) {
    final pool = offlineQuestionBank.where((q) => q.category == category);
    final easy = pool.where((q) => q.difficulty <= 1).length;
    return pool.length >= ladderMaturityThreshold && easy >= 10;
  }

  test('each level band has enough prompt-distinct questions', () {
    final repository = MockZanKurdRepository();
    for (final category in repository.categories) {
      if (!isMature(category)) continue;
      for (final level in repository.levelsForCategory(category)) {
        final distinctPrompts = offlineQuestionBank
            .where(
              (q) =>
                  q.category == category &&
                  q.difficulty >= level.difficultyMin &&
                  q.difficulty <= level.difficultyMax,
            )
            .map((q) => q.prompt.trim())
            .toSet()
            .length;
        expect(
          distinctPrompts,
          greaterThanOrEqualTo(level.questionCount),
          reason:
              '$category / ${level.title}: ${level.questionCount} benzersiz '
              'prompt gerekiyor, $distinctPrompts var',
        );
      }
    }
  });

  test('local question image references point to bundled assets', () {
    final missing = <String>[];
    for (final question in offlineQuestionBank.where((q) => q.hasImage)) {
      final imageUrl = question.imageUrl!;
      if (!imageUrl.startsWith('asset://')) continue;
      final path = imageUrl.replaceFirst('asset://', '');
      if (!File(path).existsSync()) {
        missing.add('${question.id}: $path');
      }
    }

    expect(missing, isEmpty);
  });

  // Her kategori, tanımlı 5 seviyenin her birini farklı sorularla
  // doldurabilmeli; aksi halde seviye quizi sessizce soruları tekrar eder.
  test(
    'every category can fill all its quiz levels with distinct questions',
    () {
      final repository = MockZanKurdRepository();
      for (final category in repository.categories) {
        if (!isMature(category)) continue;
        for (final level in repository.levelsForCategory(category)) {
          final pool = offlineQuestionBank
              .where(
                (q) =>
                    q.category == category &&
                    q.difficulty >= level.difficultyMin &&
                    q.difficulty <= level.difficultyMax,
              )
              .length;
          expect(
            pool,
            greaterThanOrEqualTo(level.questionCount),
            reason:
                '$category / ${level.title}: needs ${level.questionCount} '
                'distinct questions at difficulty '
                '${level.difficultyMin}-${level.difficultyMax}, has $pool',
          );
        }
      }
    },
  );
}
