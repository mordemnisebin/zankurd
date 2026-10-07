import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Alt kategori atamasının dürüstlüğünü ölçer: id kaderi belirlemez,
/// eşleşmeyen soru sahte bir konu almaz, "10 soru" vaadi ancak yeterli
/// gerçek içerik olan alt kategoriler için verilir.
///
/// ## Kusur
///
/// `SubcategoryConfig.getSubcategoryId` anahtar kelime eşleşmesi bulamazsa
/// `question.id.hashCode.abs() % list.length` ile RASTGELE bir alt
/// kategoriye düşüyordu. Ölçüm (2026-09-28, oynanabilir banka): Dîrok'un
/// 157 sorusunun 48'i böyle yerleşiyordu — "Dîroka Kevn" (antik tarih)
/// seviyeleri modern tarih ya da şahsiyet sorusu gösterebiliyordu. Bazı
/// alt kategoriler neredeyse boş bir vaatti: Muzîk › Muzîka Nûjen'in hiç
/// gerçek eşleşmesi yoktu, Çand › Dastangotin 3, Çand › Tiştonek 2,
/// Sînema › Yılmaz Güney 2, Sînema › Belgefîlm 1 — ama
/// hepsinin 10 soruluk ilk seviyesi yine de "doluydu", komşu alt
/// kategorilerin ilgisiz sorularıyla.
///
/// ## Niçin sessiz kalırdı
///
/// Var olan her seçim testi tek tek doğruydu: tur tam uzunluktaydı, tekrar
/// yoktu, sızıntı yoktu. Hiçbiri sorunun GERÇEKTEN seçtiği alt kategoriye ait
/// olup olmadığını sormuyordu. `id.hashCode` her koşuda aynı sonucu ürettiği
/// için kusur da hep aynı biçimde, hep sessizce tekrarlanıyordu — hiçbir
/// test id'yi DEĞİŞTİRİP sonucun değişip değişmediğine bakmamıştı.
///
/// ## Bu dosya ne ölçer
///
/// 1. Eşleşme yoksa etiket boş kalır; id'nin kendisi sonucu belirlemez.
/// 2. `visibleFor` eşiği (`kMinSubcategoryQuestions`), gerçek bankadaki
///    anahtar-kelime-eşleşmeli sayımla birebir tutarlıdır.
/// 3. `loadLevelQuestions` tamamlama sırasını (önce eşleşen, sonra genel,
///    ancak genel de tükenirse başka alt kategori) gerçekten uyguluyor —
///    gerçek bankanın rastgeleliği karışmasın diye küçük, sabit bir sahte
///    banka üzerinde.
void main() {
  test('konu çeldiriciden değil, soru metni ve doğru cevaptan gelir', () {
    // Bir ritim sorusunun çeldiricisinde "stran" geçince soru dengbêjliğe,
    // bir halay sorusunun çeldiricisi "Destana Memê Alan" olunca destanlara
    // düşüyordu (2026-09-28). Çeldirici başka bir alt konudan seçilir.
    const rhythm = QuizQuestion(
      id: 'rhythm',
      category: 'Muzîk',
      prompt: 'Di muzîka kurdî de rîtm bi çi re têkildar e?',
      answers: ['lêdana rêkûpêk', 'stranên dengbêjan', 'X2', 'X3'],
      correctAnswer: 'lêdana rêkûpêk',
      explanation: 'Test açıklaması yeterince uzun olsun diye buraya yazıldı.',
    );
    expect(SubcategoryConfig.getSubcategoryId(rhythm), isEmpty);

    const halay = QuizQuestion(
      id: 'halay',
      category: 'Çand',
      prompt: 'Govenda kurdî bi çi tê naskirin?',
      answers: ['bi hevgirtina destan', 'Destana Memê Alan', 'X2', 'X3'],
      correctAnswer: 'bi hevgirtina destan',
      explanation: 'Test açıklaması yeterince uzun olsun diye buraya yazıldı.',
    );
    expect(SubcategoryConfig.getSubcategoryId(halay), 'folklor');
  });

  test('"rê" alt dizesi Yılmaz Güney alt kategorisine çekmez', () {
    // "berê", "rêz", "rasterast" gibi kelimeler iki harflik "rê" anahtar
    // kelimesiyle eşleşiyor, çekim tekniği soruları bu alt kategoriye
    // düşüyordu.
    const technique = QuizQuestion(
      id: 'technique',
      category: 'Sînema',
      prompt:
          'Dîmenê ku kamera rasterast ji jor ve dinêre, berê çi dihat '
          'gotin?',
      answers: ['dîmena ji jor', 'X1', 'X2', 'X3'],
      correctAnswer: 'dîmena ji jor',
      explanation: 'Test açıklaması yeterince uzun olsun diye buraya yazıldı.',
    );
    expect(
      SubcategoryConfig.getSubcategoryId(technique),
      isNot('yilmaz_guney'),
    );
  });

  test('Kurmancî yazımla "Yilmaz Guney" de kendi alt kategorisine düşer', () {
    // Kurmancî alfabede ı ve ü yok; banka Kurmancî cümlede adı "Yilmaz
    // Guney" yazıyor. Anahtar kelimeler yalnız Türkçe yazımı tanırken bu
    // soru (edit_sinema_0006'nın kalıbı) genel havuza düşüyordu.
    const grave = QuizQuestion(
      id: 'grave',
      category: 'Sînema',
      prompt: 'Gora Yilmaz Guney li kîjan bajarî ye?',
      answers: ['Parîs', 'X1', 'X2', 'X3'],
      correctAnswer: 'Parîs',
      explanation: 'Test açıklaması yeterince uzun olsun diye buraya yazıldı.',
    );
    expect(SubcategoryConfig.getSubcategoryId(grave), 'yilmaz_guney');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SeenQuestionStore.resetInstance();
  });

  group('getSubcategoryId — id kaderi belirlemez', () {
    test('anahtar kelimesiz soru id ne olursa olsun genel kalır (boş)', () {
      // Eski kusur `id.hashCode % n` üzerinden çalışıyordu: bazı id'ler
      // "şans eseri" doğru görünen bir alt kategoriye düşerken bazıları
      // yanlışına düşüyordu. Yeni davranış id'den TAMAMEN bağımsız olmalı;
      // birkaç farklı biçimde id deneriz.
      for (final id in ['a', 'zzzzzz', '12345', 'weird-id-!@#', 'q_999999']) {
        final q = QuizQuestion(
          id: id,
          category: 'Ziman',
          prompt: 'Ev pirsek gelemperî ye, mijar taybet nîne.',
          answers: const ['Cevabê Y', 'X1', 'X2', 'X3'],
          correctAnswer: 'Cevabê Y',
          explanation:
              'Test açıklaması yeterince uzun olsun diye buraya yazıldı.',
        );
        expect(
          SubcategoryConfig.getSubcategoryId(q),
          isEmpty,
          reason: 'id="$id" için beklenen: boş (genel havuz)',
        );
        expect(
          SubcategoryConfig.getSubcategoryLabel(q, true),
          isEmpty,
          reason: 'Rastgele bir başlık uydurmak da aynı yalanı söyler.',
        );
        expect(SubcategoryConfig.getSubcategoryLabel(q, false), isEmpty);
      }
    });

    test(
      'anahtar kelimeli soru id ne olursa olsun aynı alt kategoriye düşer',
      () {
        for (final id in ['a', 'zzzzzz', '12345', 'weird-id-!@#', 'q_999999']) {
          final q = QuizQuestion(
            id: id,
            category: 'Muzîk',
            prompt: 'Dengbêj kî ye û kilam çawa tê gotin ($id)?',
            answers: const ['Stranbêjê devkî', 'X1', 'X2', 'X3'],
            correctAnswer: 'Stranbêjê devkî',
            explanation:
                'Test açıklaması yeterince uzun olsun diye buraya yazıldı.',
          );
          expect(
            SubcategoryConfig.getSubcategoryId(q),
            'dengbeji',
            reason:
                'id="$id" sonucu değiştirmemeli — konu id\'den değil '
                'metinden gelir.',
          );
        }
      },
    );
  });

  group('visibleFor — eşik gerçek sayımla tutarlı', () {
    test(
      'her kategoride görünür/gizli ayrımı gerçek eşleşme sayımıyla örtüşür',
      () {
        // 2026-09-02 karantina sonrası oynanabilir banka >1000 soru; bu satır
        // testin gerçekten üretim bankasıyla çalıştığını doğrular — aksi
        // hâlde testin altında yalnız curated (45 soruluk) fixture döner ve
        // hiçbir alt kategori hiçbir zaman eşiği aşmaz (bkz.
        // subcategory_pool_width_test.dart, aynı önlem).
        expect(
          QuestionBankLoader.instance.allQuestions.length,
          greaterThan(1000),
        );
        final playable = MockZanKurdRepository().playableQuestions;

        final report = StringBuffer();
        for (final category in SubcategoryConfig.subcategories.keys) {
          final list = SubcategoryConfig.subcategories[category]!;
          final counts = <String, int>{
            for (final sub in list)
              sub.id: playable
                  .where((q) => q.category == category)
                  .where((q) => SubcategoryConfig.getSubcategoryId(q) == sub.id)
                  .length,
          };
          final visibleIds = SubcategoryConfig.visibleFor(
            category,
            playable,
          ).map((s) => s.id).toSet();

          final hidden = <String>[];
          for (final sub in list) {
            final count = counts[sub.id] ?? 0;
            final shouldBeVisible =
                count >= SubcategoryConfig.kMinSubcategoryQuestions;
            expect(
              visibleIds.contains(sub.id),
              shouldBeVisible,
              reason:
                  '$category › ${sub.id}: $count eşleşen soru, eşik '
                  '${SubcategoryConfig.kMinSubcategoryQuestions}. '
                  '${shouldBeVisible ? "Görünür olmalıydı." : "Gizli kalmalıydı."}',
            );
            if (!shouldBeVisible) hidden.add('${sub.id} ($count)');
          }
          final visibleWithCounts = list
              .where((s) => visibleIds.contains(s.id))
              .map((s) => '${s.id} (${counts[s.id]})')
              .join(', ');
          report.writeln(
            '  $category: görünür = ${visibleWithCounts.isEmpty ? "-" : visibleWithCounts} '
            '· gizli = ${hidden.isEmpty ? "-" : hidden.join(", ")}',
          );
        }

        // Bu bir iddia değil, bir rapordur: hangi alt kategorilerin bugün
        // gizli olduğunu (ve kaç gerçek eşleşmeleri olduğunu) elle okunabilir
        // biçimde bırakır — eşiği geçtikleri gün otomatik görünür olacaklar.
        // ignore: avoid_print
        print('--- Alt kategori görünürlüğü (gerçek oynanabilir banka) ---');
        // ignore: avoid_print
        print(report.toString());
      },
    );
  });

  group('loadLevelQuestions — tamamlama sırası dürüst', () {
    // 2026-10-02: alt konu yolu artık havuzu seviyelere ÇAKIŞMAYAN dilimlerle
    // böler (bkz. [SubcategoryLevelPlan]); bu yüzden tamamlama sırası artık
    // bir seviyenin değil BEŞ seviyenin birlikte davranışıdır. Sahte banka:
    // 3 eşleşen (r), 5 genel (g), 2 başka alt konu (p) — hepsi zorluk 1.
    Future<List<List<String>>> loadAllLevels(
      MockZanKurdRepository repository,
    ) async {
      final levels = repository.levelsForCategory(
        'Ziman',
        subCategory: 'reziman',
      );
      return [
        for (final level in levels)
          [
            for (final q in await repository.loadLevelQuestions(
              category: 'Ziman',
              difficultyMin: level.difficultyMin,
              difficultyMax: level.difficultyMax,
              subCategory: 'reziman',
              levelNumber: level.number,
              limit: level.questionCount,
            ))
              q.id,
          ],
      ];
    }

    test(
      'genel sorular yetiyorsa başka alt kategoriden HİÇ soru gelmez',
      () async {
        final repository = _SyntheticSubcategoryRepository();
        final levels = await loadAllLevels(repository);

        // 1. seviye: 1 eşleşen + 4 dolgu; genel(5) ihtiyacı (4) karşılar →
        // "peyvnasi" (p*) hiç görünmemeli.
        expect(levels[0].length, 5);
        expect(
          levels[0].where((id) => id.startsWith('p')),
          isEmpty,
          reason:
              'Genel sorular (g*) 1. seviyenin ihtiyacını karşılıyor; başka '
              'alt kategoriden (p*, peyvnasi) soru gelmemeliydi.',
        );
        expect(
          levels[0].where((id) => id.startsWith('r')),
          hasLength(1),
          reason: 'Eşleşen (reziman) dilim turdan dışlanmamalı.',
        );
      },
    );

    test(
      'genel sorular yetmezse ANCAK O ZAMAN başka alt kategoriden tamamlanır; '
      'hiçbir soru iki seviyede yok',
      () async {
        final repository = _SyntheticSubcategoryRepository();
        final levels = await loadAllLevels(repository);

        final all = [for (final level in levels) ...level];
        expect(
          all.toSet().length,
          all.length,
          reason: 'Aynı yolun iki seviyesinde aynı soru çıkmamalı: $levels',
        );
        expect(
          all.toSet(),
          {'r1', 'r2', 'r3', 'g1', 'g2', 'g3', 'g4', 'g5', 'p1', 'p2'},
          reason:
              'Havuzun TAMAMI (3 eşleşen + 5 genel + 2 başka alt kategori) '
              'dağıtılır; genel tükenince başka alt kategoriye düşülür.',
        );
        // p ancak genel (g) tükendikten sonra: 1. seviyede yok, g'lerin
        // hepsi p'lerden ÖNCEki seviyelerde ya da aynı seviyede kullanıldı.
        final firstP = levels.indexWhere(
          (level) => level.any((id) => id.startsWith('p')),
        );
        final lastG = levels.lastIndexWhere(
          (level) => level.any((id) => id.startsWith('g')),
        );
        expect(firstP, greaterThan(0));
        expect(lastG, lessThanOrEqualTo(firstP));
      },
    );

    test(
      'dolgu oturum tohumuna göre değişir, oturum içinde kararlıdır',
      () async {
        final a = await _SyntheticSubcategoryRepository(seed: 1).loadFirstIds();
        final aAgain = await _SyntheticSubcategoryRepository(
          seed: 1,
        ).loadFirstIds();
        expect(aAgain, a, reason: 'Aynı tohum aynı dolguyu vermeli.');

        final fillers = <String>{};
        for (var seed = 1; seed <= 12; seed++) {
          fillers.addAll(
            await _SyntheticSubcategoryRepository(seed: seed).loadFirstIds(),
          );
        }
        expect(
          fillers.where((id) => id.startsWith('g')).length,
          greaterThan(4),
          reason:
              'Dolgu hep aynı ilk genel sorulardan oluşuyordu '
              '(`general.take`, karıştırmadan).',
        );
      },
    );
  });
}

/// Alt konu seviye planının tamamlama sırasını (eşleşen → genel → başka alt
/// kategori) laboratuvar koşullarında, gerçek bankanın büyüklüğü ve
/// rastgeleliği karışmadan ölçmek için sabit, sızıntısız, tekrarsız bir soru
/// kümesi. Her sorunun `correctAnswer`ı benzersizdir ki
/// `QuestionSetPolicy.withoutLeaks` hiçbirini elemesin — aksi hâlde seçilen
/// küme daha küçük çıkar ve testin sayım varsayımları bozulur.
class _SyntheticSubcategoryRepository extends MockZanKurdRepository {
  _SyntheticSubcategoryRepository({int seed = 7}) : super(levelSeed: seed);

  /// 1. seviyenin kimlikleri (dolgu tohuma bağlı olduğu için).
  Future<Set<String>> loadFirstIds() async {
    final level = levelsForCategory('Ziman', subCategory: 'reziman').first;
    final questions = await loadLevelQuestions(
      category: 'Ziman',
      difficultyMin: level.difficultyMin,
      difficultyMax: level.difficultyMax,
      subCategory: 'reziman',
      levelNumber: level.number,
      limit: level.questionCount,
    );
    return {for (final q in questions) q.id};
  }

  @override
  List<QuizQuestion> get questions => [
    // 'rêziman' anahtar kelimesiyle eşleşen 3 soru.
    for (var i = 1; i <= 3; i++) _q('r$i', 'Ez pirsa rêziman a $i pirsim.'),
    // Hiçbir alt kategoriyle eşleşmeyen 5 genel soru.
    for (var i = 1; i <= 5; i++)
      _q('g$i', 'Pirsa gelemperî ya $i, mijar taybet nîne.'),
    // Başka bir alt kategoriye ('peyvnasi', 'ferheng' anahtar kelimesiyle)
    // eşleşen 2 soru — genel havuz yetmediği sürece hiç seçilmemeli.
    for (var i = 1; i <= 2; i++) _q('p$i', 'Peyva ferheng a $i çi ye.'),
  ];

  static QuizQuestion _q(String id, String prompt) => QuizQuestion(
    id: id,
    category: 'Ziman',
    prompt: prompt,
    answers: ['Cevabê $id', 'X1-$id', 'X2-$id', 'X3-$id'],
    correctAnswer: 'Cevabê $id',
    explanation: 'Test açıklaması yeterince uzun olsun diye buraya yazıldı.',
    difficulty: 1,
  );
}
