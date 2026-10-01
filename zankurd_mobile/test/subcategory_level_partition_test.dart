import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/data/subcategory_level_plan.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Bir alt konunun BEŞ seviyesini birlikte ölçer (2026-10-02 denge denetimi).
///
/// ## Kusur
///
/// Alt konu yolu kategori yolunun zorluk bantlarını alt konunun kendi
/// (küçük) havuzuna uyguluyordu. Ölçüm (gerçek banka, 16 alt konu): Bingeh
/// (2. seviye) Destpêk'in 10 sorusundan 6–10'unu tekrar ediyordu; Mamoste
/// (5. seviye) 15 sorunun 9–14'ü ilgisiz dolguydu ve dolgu karıştırılmadan
/// alındığı için hep aynı ilk genel sorulardı.
///
/// ## Niçin sessiz kalırdı
///
/// Var olan her bekçi TEK seviyeye baktı (tam uzunluk, sızıntı yok, tekrar
/// yok). Tekrar seviyeler ARASINDAydı; seviyeler ayrı çağrılarda yüklendiği
/// için hiçbir çağrı bunu göremezdi ve hiçbir test aynı yolun beş seviyesini
/// yan yana koymamıştı.
///
/// ## Bu dosya ne ölçer
///
/// * Aynı alt konu yolunun iki seviyesinde aynı soru çıkmaz.
/// * Her görünür alt konunun her seviyesi en az %80 konudaşıdır.
/// * 1. seviye 5. seviyeden kolaydır (ortalama zorluk).
/// * Kart ne diyorsa tur o kadar soru verir (gerçek boyut).
/// * Kategori yolu DEĞİŞMEDİ (seviye tanımları ve bantları aynı).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SeenQuestionStore.resetInstance();
  });

  test('gerçek banka yüklü (bekçi kör kalmasın)', () {
    expect(QuestionBankLoader.instance.allQuestions.length, greaterThan(1000));
  });

  test('alt konu yolunda hiçbir soru iki seviyede yok, her seviye konudaş, '
      '1. seviye 5.den kolay', () async {
    final repository = MockZanKurdRepository(levelSeed: 11);
    final playable = repository.playableQuestions;
    final failures = <String>[];
    final report = StringBuffer();
    var checkedSubcategories = 0;

    for (final category in repository.categories) {
      for (final sub in SubcategoryConfig.visibleFor(category, playable)) {
        checkedSubcategories++;
        final levels = repository.levelsForCategory(
          category,
          subCategory: sub.id,
        );
        final served = <int, List<QuizQuestion>>{};
        for (final level in levels) {
          served[level.number] = await repository.loadLevelQuestions(
            category: category,
            difficultyMin: level.difficultyMin,
            difficultyMax: level.difficultyMax,
            subCategory: sub.id,
            levelNumber: level.number,
            limit: level.questionCount,
          );
        }

        // 1) Seviyeler arası çakışma yok.
        final seenAt = <String, int>{};
        for (final entry in served.entries) {
          for (final q in entry.value) {
            final earlier = seenAt[q.id];
            if (earlier != null) {
              failures.add(
                '$category › ${sub.id}: ${q.id} hem $earlier. hem '
                '${entry.key}. seviyede',
              );
            }
            seenAt[q.id] = entry.key;
          }
        }

        // 2) Kart gerçek boyutu söylüyor.
        for (final level in levels) {
          final got = served[level.number]!.length;
          if (got != level.questionCount) {
            failures.add(
              '$category › ${sub.id} › ${level.number}. seviye: kart '
              '${level.questionCount} diyor, $got geldi',
            );
          }
        }

        // 3) Konudaşlık ≥ %80.
        final ratios = <String>[];
        for (final level in levels) {
          final list = served[level.number]!;
          if (list.isEmpty) continue;
          final onTopic = list
              .where((q) => SubcategoryConfig.getSubcategoryId(q) == sub.id)
              .length;
          final ratio = onTopic / list.length;
          ratios.add('${(ratio * 100).round()}%');
          if (ratio < 0.8) {
            failures.add(
              '$category › ${sub.id} › ${level.number}. seviye: '
              '$onTopic/${list.length} konudaş',
            );
          }
        }

        // 4) 1. seviye 5. seviyeden kolay (ortalama zorluk).
        double avg(List<QuizQuestion> list) => list.isEmpty
            ? 0
            : list.map((q) => q.difficulty).reduce((a, b) => a + b) /
                  list.length;
        final first = avg(served[1]!);
        final last = avg(served[5]!);
        if (first > last) {
          failures.add(
            '$category › ${sub.id}: 1. seviye ortalaması $first, '
            '5. seviye $last — kolay seviye daha zor',
          );
        }

        report.writeln(
          '  $category › ${sub.id}: boyut '
          '${levels.map((l) => l.questionCount).join("/")} · konudaş '
          '${ratios.join("/")} · zorluk ort. '
          '${first.toStringAsFixed(1)}→${last.toStringAsFixed(1)}',
        );
      }
    }

    expect(checkedSubcategories, greaterThan(15));
    // ignore: avoid_print
    print('--- Alt konu seviye planı (gerçek banka) ---\n$report');
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('plan saf bir fonksiyon: aynı tohum aynı plan, çakışmasız dilimler', () {
    final repository = MockZanKurdRepository(levelSeed: 3);
    final playable = repository.playableQuestions;
    for (final category in repository.categories) {
      for (final sub in SubcategoryConfig.visibleFor(category, playable)) {
        SubcategoryLevelPlan build(int seed) => SubcategoryLevelPlan.build(
          standardLevels: repository.levelsForCategory(category),
          categoryPool: [
            for (final q in playable)
              if (q.category == category) q,
          ],
          subCategory: sub.id,
          seed: seed,
        );
        final plan = build(3);
        final again = build(3);
        expect(
          [for (final l in plan.levels) l.candidates.map((q) => q.id).toList()],
          [
            for (final l in again.levels)
              l.candidates.map((q) => q.id).toList(),
          ],
          reason: '$category › ${sub.id}: aynı tohum aynı planı vermeli',
        );
        final ids = [
          for (final l in plan.levels) ...l.candidates.map((q) => q.id),
        ];
        expect(
          ids.toSet().length,
          ids.length,
          reason: '$category › ${sub.id}: dilim/dolgu çakışması',
        );
      }
    }
  });

  test(
    'havuz 25 ve üstündeyse dolgu YOK; seviye boyutu havuzun beşte biri',
    () {
      final repository = MockZanKurdRepository(levelSeed: 5);
      final playable = repository.playableQuestions;
      for (final category in repository.categories) {
        for (final sub in SubcategoryConfig.visibleFor(category, playable)) {
          final plan = SubcategoryLevelPlan.build(
            standardLevels: repository.levelsForCategory(category),
            categoryPool: [
              for (final q in playable)
                if (q.category == category) q,
            ],
            subCategory: sub.id,
            seed: 5,
          );
          final poolSize = plan.levels.fold<int>(
            0,
            (sum, l) => sum + l.band.length,
          );
          for (final level in plan.levels) {
            if (poolSize >= SubcategoryLevelPlan.fillerBelow) {
              expect(
                level.fillers,
                isEmpty,
                reason:
                    '$category › ${sub.id}: havuz $poolSize ≥ 25 → dolgu yok',
              );
            }
            expect(
              level.size,
              lessThanOrEqualTo(
                repository
                    .levelsForCategory(category)[level.number - 1]
                    .questionCount,
              ),
            );
            expect(level.size, greaterThanOrEqualTo(5));
          }
        }
      }
    },
  );

  test('kategori yolu değişmedi: seviye tanımları ve bantlar aynı', () async {
    final repository = MockZanKurdRepository(levelSeed: 1);
    // (numara, ad, zorluk min, zorluk max, soru sayısı) — 2026-10-02 öncesiyle
    // birebir.
    const expected = [
      (1, 'Destpêk', 1, 2, 10),
      (2, 'Bingeh', 1, 2, 10),
      (3, 'Navîn', 2, 3, 12),
      (4, 'Pêşketî', 3, 4, 12),
      (5, 'Mamoste', 4, 5, 15),
    ];
    for (final category in repository.categories) {
      final levels = repository.levelsForCategory(category);
      expect(
        [
          for (final l in levels)
            (
              l.number,
              l.title,
              l.difficultyMin,
              l.difficultyMax,
              l.questionCount,
            ),
        ],
        expected,
        reason: '$category: kategori yolunun seviye tanımı değişmemeli',
      );
      // Alt konu verilmeyen ve 'gisti' (tüm kategori) çağrıları kategori
      // yoludur: yalnız kategori + zorluk bandı.
      for (final subCategory in <String?>[null, 'gisti']) {
        expect(
          [
            for (final l in repository.levelsForCategory(
              category,
              subCategory: subCategory,
            ))
              l.questionCount,
          ],
          [10, 10, 12, 12, 15],
        );
        for (final level in levels) {
          final questions = await repository.loadLevelQuestions(
            category: category,
            difficultyMin: level.difficultyMin,
            difficultyMax: level.difficultyMax,
            subCategory: subCategory,
            levelNumber: level.number,
            limit: level.questionCount,
          );
          expect(
            questions.every(
              (q) =>
                  q.category == category &&
                  q.difficulty >= level.difficultyMin &&
                  q.difficulty <= level.difficultyMax,
            ),
            isTrue,
            reason: '$category ${level.number}. seviye ($subCategory)',
          );
        }
      }
    }
  });
}
